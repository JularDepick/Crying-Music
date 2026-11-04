/* 泣水音乐 验证码服务: 验证码的发送与校验
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * 两个接口:
 *   发送  POST api/code/send    {"email":"..."}            -> 发一封六位验证码邮件
 *   校验  POST api/code/verify  {"email":"...","code":"..."} -> 通过时回一份带签名的登录凭证
 * 登录凭证的签名覆盖"邮箱 + 签发时刻", 客户端用同一个客户端密钥复核后落盘, 有效期由客户端决定.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import { randomInt } from "node:crypto";
import type { ApiConfig } from "./config.ts";
import type { ApiStore } from "./db.ts";
import type { MailService } from "./mailer.ts";
import { codeDigestOf, loginSignOf, sameHex } from "./sign.ts";
import {
    clientIpOf,
    headerOf,
    readJsonBody,
    replyError,
    replyJson,
    stampOf,
    stringField
} from "./http.ts";

/* 邮箱的格式与长度上限: 只做最基本的形状校验, 送达与否由 SMTP 决定 */
const EMAIL_PATTERN = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,24}$/;
const EMAIL_MAX_LENGTH = 254;
/* 验证码固定六位数字 */
const CODE_PATTERN = /^[0-9]{6}$/;

/* 规整邮箱: 去掉首尾空白并统一小写, 大小写不同视为同一邮箱 */
function normalizeEmail(raw: string): string {
    return raw.trim().toLowerCase();
}

export class CodeRoutes {
    private readonly config: ApiConfig;
    private readonly store: ApiStore;
    private readonly mail: MailService;

    constructor(config: ApiConfig, store: ApiStore, mail: MailService) {
        this.config = config;
        this.store = store;
        this.mail = mail;
    }

    /* 发送验证码: 冷却与每日上限都在写库前判掉 */
    async send(req: IncomingMessage, res: ServerResponse): Promise<void> {
        let payload: unknown = null;
        try {
            payload = await readJsonBody(req, this.config.bodyLimitBytes);
        } catch (error) {
            replyError(res, 400, "bad_request", "请求体不合法: " + String(error));
            return;
        }
        const email = normalizeEmail(stringField(payload, "email"));
        if (email === "" || email.length > EMAIL_MAX_LENGTH || EMAIL_PATTERN.test(email) === false) {
            replyError(res, 400, "invalid_email", "邮箱地址格式不正确");
            return;
        }
        const now = Date.now();
        const sinceLast = this.store.sinceLastSendMs(email, now);
        const cooldownMs = this.config.sendCooldownSeconds * 1000;
        if (sinceLast < cooldownMs) {
            const retryAfter = Math.ceil((cooldownMs - sinceLast) / 1000);
            console.warn("[发送] 冷却中: " + email + ", 还需 " + String(retryAfter) + " 秒");
            replyError(res, 429, "cooldown",
                       "发送过于频繁, 请 " + String(retryAfter) + " 秒后再试",
                       { retryAfter: retryAfter });
            return;
        }
        const daily = this.store.sendCountSince(email, now - 86400000);
        if (daily >= this.config.sendDailyLimit) {
            console.warn("[发送] 超出每日上限: " + email + ", 已发 " + String(daily) + " 次");
            replyError(res, 429, "daily_limit", "该邮箱今日获取验证码的次数已达上限, 请明天再试");
            return;
        }
        const code = String(randomInt(100000, 1000000));
        const expiresAt = now + this.config.codeTtlSeconds * 1000;
        this.store.saveCode({
            email: email,
            codeHash: codeDigestOf(this.config.clientSecret, email, code),
            expiresAt: expiresAt,
            sentAt: now,
            attempts: 0
        });
        try {
            await this.mail.sendCode(email, code, Math.max(1, Math.round(this.config.codeTtlSeconds / 60)));
        } catch (error) {
            /* 邮件没发出去就把这条验证码撤掉, 免得占着冷却时间又拿不到码 */
            this.store.dropCode(email);
            console.error("[发送] 邮件投递失败: " + email + ", " + String(error));
            replyError(res, 502, "smtp_failed", "验证码邮件发送失败, 请稍后再试");
            return;
        }
        console.log("[发送] 已发送: " + email + ", 过期 " + stampOf(expiresAt)
                    + ", 来源 " + clientIpOf(req));
        replyJson(res, 200, {
            ok: true,
            email: email,
            expiresIn: this.config.codeTtlSeconds,
            cooldown: this.config.sendCooldownSeconds,
            message: "验证码已发送至 " + email
        });
    }

    /* 校验验证码: 成功后签发带签名的登录凭证, 并把这次登录记进流水 */
    async verify(req: IncomingMessage, res: ServerResponse): Promise<void> {
        let payload: unknown = null;
        try {
            payload = await readJsonBody(req, this.config.bodyLimitBytes);
        } catch (error) {
            replyError(res, 400, "bad_request", "请求体不合法: " + String(error));
            return;
        }
        const email = normalizeEmail(stringField(payload, "email"));
        const code = stringField(payload, "code").trim();
        if (email === "" || email.length > EMAIL_MAX_LENGTH || EMAIL_PATTERN.test(email) === false) {
            replyError(res, 400, "invalid_email", "邮箱地址格式不正确");
            return;
        }
        if (CODE_PATTERN.test(code) === false) {
            replyError(res, 400, "invalid_code", "验证码为六位数字");
            return;
        }
        const now = Date.now();
        const record = this.store.codeOf(email);
        if (record === null) {
            replyError(res, 400, "no_code", "验证码不存在或已失效, 请重新获取");
            return;
        }
        if (record.expiresAt <= now) {
            this.store.dropCode(email);
            replyError(res, 400, "expired", "验证码已过期, 请重新获取");
            return;
        }
        if (record.attempts >= this.config.verifyMaxAttempts) {
            this.store.dropCode(email);
            replyError(res, 400, "attempts_exceeded", "验证码错误次数过多, 请重新获取");
            return;
        }
        const expected = codeDigestOf(this.config.clientSecret, email, code);
        if (sameHex(expected, record.codeHash) === false) {
            this.store.bumpAttempts(email);
            const left = Math.max(0, this.config.verifyMaxAttempts - record.attempts - 1);
            console.warn("[校验] 验证码错误: " + email + ", 剩余 " + String(left) + " 次");
            replyError(res, 400, "bad_code",
                       "验证码不正确" + (left > 0 ? ", 还可尝试 " + String(left) + " 次" : ""),
                       { remaining: left });
            return;
        }
        this.store.dropCode(email);
        const ip = clientIpOf(req);
        this.store.recordLogin(email, now, ip);
        const sign = loginSignOf(this.config.clientSecret, email, now);
        console.log("[校验] 通过: " + email + ", 时间 " + stampOf(now) + ", 来源 " + ip);
        replyJson(res, 200, {
            ok: true,
            email: email,
            issuedAt: now,
            sign: sign,
            message: "登录成功"
        });
    }
}

/* 鉴权: 客户端内置密钥放在请求头里, 常量时间比较 */
export function authorized(req: IncomingMessage, secret: string): boolean {
    const given = headerOf(req, "x-client-secret");
    return sameHex(given, secret);
}
