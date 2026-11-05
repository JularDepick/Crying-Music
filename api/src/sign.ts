/* 泣水音乐 验证码服务: 摘要与签名
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * 验证码只存摘要, 登录凭证用同一个客户端密钥做 HMAC 签名, 客户端拿到后可以离线复核.
 */
import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

/* HMAC-SHA256 十六进制小写结果 */
export function hmacHex(key: string, message: string): string {
    return createHmac("sha256", key).update(message, "utf8").digest("hex");
}

/* SHA-256 十六进制小写结果 */
export function sha256Hex(message: string): string {
    return createHash("sha256").update(message, "utf8").digest("hex");
}

/* 验证码摘要: 把邮箱一并拌进去, 同一个验证码换个邮箱就不成立 */
export function codeDigestOf(secret: string, email: string, code: string): string {
    return hmacHex(secret, "code|" + email + "|" + code);
}

/* 登录凭证签名: 覆盖邮箱与签发时刻, 客户端按同一口径复核 */
export function loginSignOf(secret: string, email: string, issuedAt: number): string {
    return hmacHex(secret, "login|" + email + "|" + String(issuedAt));
}

/* 登录状态秘钥: 覆盖邮箱, 签发时刻与一串随机盐, 每个邮箱同时只有一条有效秘钥 */
export function sessionKeyOf(secret: string, email: string, issuedAt: number, salt: string): string {
    return hmacHex(secret, "session|" + email + "|" + String(issuedAt) + "|" + salt);
}

/* 听歌上报签名: 覆盖邮箱, 秒数, 日期与累加后的总秒数, 客户端按同一口径复核 */
export function listenSignOf(secret: string, email: string, seconds: number,
                             day: string, totalSeconds: number): string {
    return hmacHex(secret, "listen|" + email + "|" + String(seconds)
                   + "|" + day + "|" + String(totalSeconds));
}

/* 随机十六进制盐: 长度按十六进制字符计, 实际取一半字节数 */
export function saltOf(hexLength: number): string {
    const bytes = Math.max(1, Math.ceil(hexLength / 2));
    return randomBytes(bytes).toString("hex").slice(0, hexLength);
}

/* 定长十六进制串的常量时间比较: 长度不同直接判不等, 避免按位短路泄露内容 */
export function sameHex(a: string, b: string): boolean {
    const left = Buffer.from(a, "utf8");
    const right = Buffer.from(b, "utf8");
    if (left.length !== right.length || left.length === 0) {
        return false;
    }
    return timingSafeEqual(left, right);
}
