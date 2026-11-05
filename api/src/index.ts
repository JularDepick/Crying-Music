/* 泣水音乐 验证码服务: 入口
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * node --watch src/index.ts 即可运行, 也可以用 pm2 / systemd 托管.
 * 路由分两组: 验证码的发送与校验, 以及登录状态与听歌时长.
 */
import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { loadConfig } from "./config.ts";
import { ApiStore } from "./db.ts";
import { MailService } from "./mailer.ts";
import { CodeRoutes, authorized } from "./code.ts";
import { UserRoutes } from "./user.ts";
import { replyError, replyJson, sessionKeyOfHeader, stampOf } from "./http.ts";

const API_PREFIX = "/api/";

async function main(): Promise<void> {
    const config = loadConfig();
    const store = new ApiStore(config.dbFile);
    const mail = new MailService(config);
    const routes = new CodeRoutes(config, store, mail);
    const userRoutes = new UserRoutes(config, store);
    /* 过期数据每十分钟清一次, 保持库文件不无限增长 */
    const pruneTimer = setInterval(() => {
        try {
            store.prune(Date.now());
        } catch (error) {
            console.error("[维护] 清理失败: " + String(error));
        }
    }, 600000);
    pruneTimer.unref();

    const server = createServer((req: IncomingMessage, res: ServerResponse) => {
        handle(req, res).catch((error: unknown) => {
            console.error("[服务] 未捕获异常: " + String(error));
            if (res.headersSent === false) {
                replyError(res, 500, "internal_error", "服务内部错误");
            }
        });
    });

    async function handle(req: IncomingMessage, res: ServerResponse): Promise<void> {
        const url = new URL(req.url ?? "/", "http://" + (req.headers.host ?? "localhost"));
        const path = url.pathname;
        if (path === API_PREFIX + "health") {
            replyJson(res, 200, { ok: true, service: "crying-music-code", time: Date.now() });
            return;
        }
        /* 登录状态与听歌时长另走一套分发: 身份验证用的是请求头里的登录状态秘钥 */
        if (path.indexOf(API_PREFIX + "user/") === 0) {
            await handleUser(req, res);
            return;
        }
        const isSend = (path === API_PREFIX + "code/send");
        const isVerify = (path === API_PREFIX + "code/verify");
        if (isSend === false && isVerify === false) {
            replyError(res, 404, "bad_request", "接口不存在");
            return;
        }
        if (req.method !== "POST") {
            replyError(res, 405, "bad_request", "只接受 POST");
            return;
        }
        if (authorized(req, config.clientSecret) === false) {
            console.warn("[服务] 拒绝未授权的请求: " + path + ", 来源 " + (req.socket.remoteAddress ?? ""));
            replyError(res, 401, "unauthorized", "客户端密钥无效");
            return;
        }
        if (isSend) {
            await routes.send(req, res);
            return;
        }
        await routes.verify(req, res);
    }

    /* 登录状态与听歌时长: 鉴权用客户端密钥, 身份验证用请求头里的登录状态秘钥 */
    async function handleUser(req: IncomingMessage, res: ServerResponse): Promise<void> {
        const url = new URL(req.url ?? "/", "http://" + (req.headers.host ?? "localhost"));
        const path = url.pathname;
        const isLogout = (path === API_PREFIX + "user/logout");
        const isRefresh = (path === API_PREFIX + "user/refresh");
        const isListen = (path === API_PREFIX + "user/listen");
        const isProfile = (path === API_PREFIX + "user/profile");
        if (isLogout === false && isRefresh === false && isListen === false && isProfile === false) {
            replyError(res, 404, "bad_request", "接口不存在");
            return;
        }
        /* 资料查询用 GET, 其余三个操作用 POST */
        if (isProfile === true) {
            if (req.method !== "GET") {
                replyError(res, 405, "bad_request", "只接受 GET");
                return;
            }
        } else if (req.method !== "POST") {
            replyError(res, 405, "bad_request", "只接受 POST");
            return;
        }
        if (authorized(req, config.clientSecret) === false) {
            console.warn("[服务] 拒绝未授权的用户请求: " + path + ", 来源 "
                         + (req.socket.remoteAddress ?? ""));
            replyError(res, 401, "unauthorized", "客户端密钥无效");
            return;
        }
        if (sessionKeyOfHeader(req) === "") {
            console.warn("[服务] 拒绝缺少登录状态秘钥的请求: " + path + ", 来源 "
                         + (req.socket.remoteAddress ?? ""));
            replyError(res, 401, "session_required", "缺少登录状态秘钥, 请重新登录");
            return;
        }
        if (isLogout) {
            userRoutes.logout(req, res);
            return;
        }
        if (isRefresh) {
            userRoutes.refresh(req, res);
            return;
        }
        if (isProfile) {
            userRoutes.profile(req, res);
            return;
        }
        userRoutes.listen(req, res);
    }

    /* 地址留空时交给系统按默认的双栈地址监听, 有值时只绑在该地址上 */
    const hostText = (config.host === "" ? "默认地址" : config.host);
    server.on("error", (error: Error) => {
        console.error("[服务] 监听失败: " + hostText + ":" + String(config.port) + ", " + error.message);
        store.close();
        process.exit(1);
    });
    const onListening = (): void => {
        console.log("[服务] 已启动: 地址 " + hostText + ", 端口 " + String(config.port)
                    + ", 数据库 " + config.dbFile);
        console.log("[服务] 验证码有效期 " + String(config.codeTtlSeconds) + " 秒, 发送冷却 "
                    + String(config.sendCooldownSeconds) + " 秒, 每日上限 "
                    + String(config.sendDailyLimit) + " 次");
        void mail.verifyConnection().then((ok: boolean) => {
            console.log("[服务] SMTP 自检: " + (ok ? "通过" : "未通过, 发送可能失败"));
        });
    };
    if (config.host === "") {
        server.listen(config.port, onListening);
    } else {
        server.listen(config.port, config.host, onListening);
    }

    const shutdown = (signal: string): void => {
        console.log("[服务] 收到 " + signal + ", 正在关闭: " + stampOf(Date.now()));
        clearInterval(pruneTimer);
        server.close(() => {
            store.close();
            process.exit(0);
        });
    };
    process.on("SIGINT", () => {
        shutdown("SIGINT");
    });
    process.on("SIGTERM", () => {
        shutdown("SIGTERM");
    });
}

main().catch((error: unknown) => {
    console.error("[服务] 启动失败: " + String(error));
    process.exit(1);
});
