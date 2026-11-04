/* 泣水音乐 验证码服务: HTTP 基础设施
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * 不引入 Web 框架: 只有两三个接口, 需要的只是 JSON 收发, 请求体上限与客户端地址.
 */
import type { IncomingMessage, ServerResponse } from "node:http";

/* 统一的错误码: 客户端按 code 分支, message 只用于直接显示 */
export type ApiErrorCode =
    | "unauthorized"
    | "bad_request"
    | "invalid_email"
    | "invalid_code"
    | "cooldown"
    | "daily_limit"
    | "no_code"
    | "expired"
    | "attempts_exceeded"
    | "bad_code"
    | "smtp_failed"
    | "internal_error";

/* 回一份 JSON: 一律带 ok 字段, 失败时另有 code 与 message */
export function replyJson(res: ServerResponse, status: number, payload: Record<string, unknown>): void {
    const body = Buffer.from(JSON.stringify(payload), "utf8");
    res.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8",
        "Content-Length": String(body.length),
        "Cache-Control": "no-store"
    });
    res.end(body);
}

/* 回一份错误: 失败响应只有三种字段 */
export function replyError(res: ServerResponse, status: number,
                           code: ApiErrorCode, message: string,
                           extra: Record<string, unknown> = {}): void {
    const payload: Record<string, unknown> = { ok: false, code: code, message: message };
    for (const key of Object.keys(extra)) {
        payload[key] = extra[key];
    }
    replyJson(res, status, payload);
}

/* 读请求体: 超过上限立即失败, 不把大包读进内存 */
export async function readJsonBody(req: IncomingMessage, limit: number): Promise<unknown> {
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of req) {
        const part = chunk as Buffer;
        size += part.length;
        if (size > limit) {
            throw new Error("请求体过大");
        }
        chunks.push(part);
    }
    if (size === 0) {
        throw new Error("请求体为空");
    }
    const text = Buffer.concat(chunks).toString("utf8");
    return JSON.parse(text);
}

/* 客户端地址: 反向代理在前面时取 X-Forwarded-For 的第一段 */
export function clientIpOf(req: IncomingMessage): string {
    const header = req.headers["x-forwarded-for"];
    const raw = (Array.isArray(header) ? header[0] : header);
    if (typeof raw === "string" && raw !== "") {
        const first = raw.split(",")[0];
        if (first !== undefined) {
            return first.trim();
        }
    }
    return req.socket.remoteAddress ?? "";
}

/* 取请求头里的单值 */
export function headerOf(req: IncomingMessage, name: string): string {
    const raw = req.headers[name.toLowerCase()];
    if (Array.isArray(raw)) {
        return (raw.length > 0 ? raw[0] : "");
    }
    return (raw === undefined ? "" : raw);
}

/* 从 JSON 里取字符串字段: 类型不对或缺失时返回空串 */
export function stringField(payload: unknown, key: string): string {
    if (payload === null || typeof payload !== "object") {
        return "";
    }
    const value = (payload as Record<string, unknown>)[key];
    return (typeof value === "string" ? value : "");
}

/* 时间戳转日志里的可读时间: 一律用本地时区 */
export function stampOf(ms: number): string {
    const d = new Date(ms);
    const pad = (n: number): string => (n < 10 ? "0" + String(n) : String(n));
    return String(d.getFullYear()) + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
        + " " + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
}
