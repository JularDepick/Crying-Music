/* 泣水音乐 验证码服务: 入口
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * node --watch src/index.ts 即可运行, 也可以用 pm2 / systemd 托管.
 * 只有三个路由: 发送验证码, 校验验证码, 健康检查.
 */
import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { loadConfig } from "./config.ts";
import { ApiStore } from "./db.ts";
import { MailService } from "./mailer.ts";
import { CodeRoutes, authorized } from "./code.ts";
import { replyError, replyJson, stampOf } from "./http.ts";

const API_PREFIX = "/api/";

async function main(): Promise<void> {
    const config = loadConfig();
    const store = new ApiStore(config.dbFile);
    const mail = new MailService(config);
    const routes = new CodeRoutes(config, store, mail);
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

    server.listen(config.port, () => {
        console.log("[服务] 已启动: 端口 " + String(config.port) + ", 数据库 " + config.dbFile);
        console.log("[服务] 验证码有效期 " + String(config.codeTtlSeconds) + " 秒, 发送冷却 "
                    + String(config.sendCooldownSeconds) + " 秒, 每日上限 "
                    + String(config.sendDailyLimit) + " 次");
        void mail.verifyConnection().then((ok: boolean) => {
            console.log("[服务] SMTP 自检: " + (ok ? "通过" : "未通过, 发送可能失败"));
        });
    });

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
