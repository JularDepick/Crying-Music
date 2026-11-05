/* 泣水音乐 验证码服务: 登录状态与听歌时长
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * 四个接口, 全部要求请求头 X-Session-Key 带上登录状态秘钥:
 *   退出  POST api/user/logout  {}                              -> 作废本次登录状态
 *   上报  POST api/user/listen  {"seconds":10,"totalSeconds":n} -> 累加听歌秒数
 *   资料  GET  api/user/profile                                  -> 累计秒数与派生等级
 *   签到  POST api/user/refresh  {}                             -> 续期登录状态
 * 听歌时长以秒为单位按天累加, 每天最多计入 listenDailyMaxSeconds 秒;
 * 等级由累计秒数按 level = min(100, floor(55.5 * ln(t/72.2 + 1))) 派生, 其中 t = 累计秒数/18000.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import type { ApiConfig } from "./config.ts";
import type { ApiStore, SessionRecord } from "./db.ts";
import {
    clientIpOf,
    dayOf,
    readJsonBody,
    replyError,
    replyJson,
    sessionKeyOfHeader,
    stampOf
} from "./http.ts";

/* 等级的换算系数与上限: 与客户端同一套口径 */
const LEVEL_BASE = 55.5;
const LEVEL_DIVISOR = 72.2;
const LEVEL_SCALE_SECONDS = 18000;
const LEVEL_MAX = 100;

/* 累计秒数换算等级: t = 累计秒数 / 18000, 再按对数曲线取整 */
export function levelOf(totalSeconds: number): number {
    const sec = Math.max(0, Math.floor(Number(totalSeconds)));
    if (sec <= 0) {
        return 0;
    }
    const t = sec / LEVEL_SCALE_SECONDS;
    const level = Math.floor(LEVEL_BASE * Math.log(t / LEVEL_DIVISOR + 1));
    if (level < 0) {
        return 0;
    }
    return (level > LEVEL_MAX ? LEVEL_MAX : level);
}

/* 从请求里取登录状态并校验: 通过时返回记录, 失败时已经回过错误并返回 null */
function sessionOf(req: IncomingMessage, res: ServerResponse,
                   store: ApiStore, now: number): SessionRecord | null {
    const key = sessionKeyOfHeader(req);
    if (key === "") {
        replyError(res, 401, "session_required", "缺少登录状态秘钥, 请重新登录");
        return null;
    }
    const one = store.sessionOf(key);
    if (one === null) {
        replyError(res, 401, "session_required", "登录状态无效, 请重新登录");
        return null;
    }
    if (one.revokedAt > 0) {
        replyError(res, 401, "session_expired", "登录状态已退出, 请重新登录");
        return null;
    }
    if (one.expiresAt <= now) {
        replyError(res, 401, "session_expired", "登录状态已过期, 请重新登录");
        return null;
    }
    return one;
}

/* 取请求体里的正整数字段: 不是正整数时返回 0 */
function positiveInt(payload: unknown, key: string): number {
    if (payload === null || typeof payload !== "object") {
        return 0;
    }
    const raw = (payload as Record<string, unknown>)[key];
    if (typeof raw !== "number" || Number.isFinite(raw) === false) {
        return 0;
    }
    const n = Math.floor(raw);
    return (n > 0 ? n : 0);
}

export class UserRoutes {
    private readonly config: ApiConfig;
    private readonly store: ApiStore;

    constructor(config: ApiConfig, store: ApiStore) {
        this.config = config;
        this.store = store;
    }

    /* 退出登录: 作废本次登录状态, 之后该秘钥立即失效 */
    logout(req: IncomingMessage, res: ServerResponse): void {
        const now = Date.now();
        const one = sessionOf(req, res, this.store, now);
        if (one === null) {
            return;
        }
        this.store.revokeSession(one.key, now);
        console.log("[登录状态] 退出: " + one.email + ", 来源 " + clientIpOf(req));
        replyJson(res, 200, { ok: true, email: one.email, message: "已退出登录" });
    }

    /* 续期: 登录状态仍在有效期内时把到期时刻延后一个周期并落库 */
    refresh(req: IncomingMessage, res: ServerResponse): void {
        const now = Date.now();
        const one = sessionOf(req, res, this.store, now);
        if (one === null) {
            return;
        }
        const renewed = now + this.config.sessionKeepDays * 86400000;
        const changed = this.store.renewSession(one.key, renewed);
        if (changed === false) {
            replyError(res, 401, "session_expired", "登录状态已失效, 请重新登录");
            return;
        }
        console.log("[登录状态] 续期: " + one.email + ", 至 " + stampOf(renewed)
                    + ", 来源 " + clientIpOf(req));
        replyJson(res, 200, {
            ok: true,
            email: one.email,
            issuedAt: one.issuedAt,
            expiresAt: renewed,
            message: "登录状态已续期"
        });
    }

    /* 用户资料: 累计听歌秒数与派生等级 */
    profile(req: IncomingMessage, res: ServerResponse): void {
        const now = Date.now();
        const one = sessionOf(req, res, this.store, now);
        if (one === null) {
            return;
        }
        const total = this.store.listenSecondsTotal(one.email);
        replyJson(res, 200, {
            ok: true,
            email: one.email,
            totalSeconds: total,
            level: levelOf(total),
            logins: this.store.loginCountOf(one.email),
            message: "资料已获取"
        });
    }

    /* 上报听歌: 每次上报一段秒数, 当天累计到上限后不再计入 */
    listen(req: IncomingMessage, res: ServerResponse): void {
        const now = Date.now();
        const one = sessionOf(req, res, this.store, now);
        if (one === null) {
            return;
        }
        readJsonBody(req, this.config.bodyLimitBytes).then((payload: unknown) => {
            const seconds = positiveInt(payload, "seconds");
            if (seconds <= 0) {
                replyError(res, 400, "bad_request", "上报秒数必须是正整数");
                return;
            }
            const day = dayOf(now);
            const lastAt = this.store.lastListenAt(one.email, day);
            const cooldownMs = this.config.listenCooldownSeconds * 1000;
            if (lastAt > 0 && now - lastAt < cooldownMs) {
                const wait = Math.ceil((cooldownMs - (now - lastAt)) / 1000);
                replyError(res, 429, "listen_cooldown",
                           "上报过于频繁, 请 " + String(wait) + " 秒后再试", { retryAfter: wait });
                return;
            }
            const before = this.store.listenSecondsOn(one.email, day);
            /* 当天已满时直接回当前累计值, 不落流水, 让客户端不必再报 */
            if (before >= this.config.listenDailyMaxSeconds) {
                const total = this.store.listenSecondsTotal(one.email);
                replyJson(res, 200, {
                    ok: true,
                    email: one.email,
                    accepted: 0,
                    daySeconds: before,
                    totalSeconds: total,
                    level: levelOf(total),
                    dailyReached: true,
                    message: "今日听歌时长已累计满"
                });
                return;
            }
            /* 截到当天剩余额度内: 一天的最后一笔允许不足一个完整上报周期 */
            const room = this.config.listenDailyMaxSeconds - before;
            const accepted = Math.min(seconds, room);
            this.store.addListenSeconds(one.email, accepted, day, now);
            const daySeconds = before + accepted;
            const total = this.store.listenSecondsTotal(one.email);
            console.log("[听歌] 上报: " + one.email + ", 本次 " + String(accepted)
                        + " 秒, 当天 " + String(daySeconds)
                        + " 秒, 累计 " + String(total) + " 秒");
            replyJson(res, 200, {
                ok: true,
                email: one.email,
                accepted: accepted,
                daySeconds: daySeconds,
                totalSeconds: total,
                level: levelOf(total),
                dailyReached: (daySeconds >= this.config.listenDailyMaxSeconds),
                message: "已累加听歌时长"
            });
        }).catch((error: unknown) => {
            replyError(res, 400, "bad_request", "请求体不合法: " + String(error));
        });
    }
}
