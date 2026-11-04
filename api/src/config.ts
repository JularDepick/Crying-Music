/* 泣水音乐 验证码服务: 环境配置读取
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * 配置全部来自与本文件所在目录同级的 .env; 缺项按默认值兜底, 必填项缺失时拒绝启动,
 * 避免用空密钥或空 SMTP 账号把服务带起来.
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/* 服务运行所需的全部配置项 */
export interface ApiConfig {
    /* 监听端口 */
    port: number;
    /* 客户端内置密钥: 请求鉴权与登录签名共用, 只在服务端与客户端之间约定 */
    clientSecret: string;
    /* SMTP 连接参数 */
    smtpHost: string;
    smtpPort: number;
    smtpSecure: boolean;
    smtpUser: string;
    smtpPassword: string;
    /* 邮件尾部签名行 */
    smtpSignature: string;
    /* 短信验证码数据库文件, 相对路径按服务目录解析 */
    dbFile: string;
    /* 验证码有效期(秒) */
    codeTtlSeconds: number;
    /* 同一邮箱两次发送之间的最短间隔(秒) */
    sendCooldownSeconds: number;
    /* 同一邮箱 24 小时内最多发送次数 */
    sendDailyLimit: number;
    /* 同一验证码允许的校验失败次数 */
    verifyMaxAttempts: number;
    /* 单次请求体上限(字节) */
    bodyLimitBytes: number;
}

/* 服务目录: .env 与默认数据库文件都相对它定位, 与启动时的工作目录无关 */
export function serviceDir(): string {
    return dirname(fileURLToPath(import.meta.url));
}

/* 解析 .env: 只认 KEY=VALUE, 支持整行注释与成对引号, 值内的等号原样保留 */
function parseEnvFile(path: string): Map<string, string> {
    const map = new Map<string, string>();
    if (existsSync(path) === false) {
        return map;
    }
    const text = readFileSync(path, "utf8");
    const lines = text.split(/\r?\n/);
    for (const raw of lines) {
        const line = raw.trim();
        if (line === "" || line.startsWith("#")) {
            continue;
        }
        const eq = line.indexOf("=");
        if (eq <= 0) {
            continue;
        }
        const key = line.slice(0, eq).trim();
        let value = line.slice(eq + 1).trim();
        const paired = value.length >= 2
            && ((value.startsWith("\"") && value.endsWith("\""))
                || (value.startsWith("'") && value.endsWith("'")));
        if (paired) {
            value = value.slice(1, -1);
        }
        map.set(key, value);
    }
    return map;
}

/* 取整数: 缺项或非法时用默认值 */
function intOf(env: Map<string, string>, key: string, fallback: number): number {
    const raw = env.get(key);
    if (raw === undefined || raw === "") {
        return fallback;
    }
    const n = Number.parseInt(raw, 10);
    return Number.isFinite(n) ? n : fallback;
}

/* 取布尔值: 认 true/1/yes/on 四种写法, 其余按假处理 */
function boolOf(env: Map<string, string>, key: string, fallback: boolean): boolean {
    const raw = env.get(key);
    if (raw === undefined || raw === "") {
        return fallback;
    }
    const v = raw.trim().toLowerCase();
    if (v === "true" || v === "1" || v === "yes" || v === "on") {
        return true;
    }
    if (v === "false" || v === "0" || v === "no" || v === "off") {
        return false;
    }
    return fallback;
}

/* 取字符串: 缺项时返回空串 */
function textOf(env: Map<string, string>, key: string, fallback: string): string {
    const raw = env.get(key);
    if (raw === undefined) {
        return fallback;
    }
    return raw;
}

/* 读取配置: 必填项缺失时抛出异常, 由入口统一打印并退出 */
export function loadConfig(): ApiConfig {
    /* .env 与本服务目录同级: src/ 的上一级 */
    const env = parseEnvFile(resolve(serviceDir(), "..", ".env"));
    const missing: string[] = [];
    const need = (key: string): string => {
        const v = textOf(env, key, "");
        if (v === "") {
            missing.push(key);
        }
        return v;
    };
    const clientSecret = need("CLIENT_SECRET");
    const smtpHost = need("SMTP_HOST");
    const smtpUser = need("SMTP_USER");
    const smtpPassword = need("SMTP_PASSWORD");
    if (missing.length > 0) {
        throw new Error("缺少必填环境变量: " + missing.join(", "));
    }
    const dbRaw = textOf(env, "DB_FILE", "");
    const config: ApiConfig = {
        port: intOf(env, "API_PORT", 26714),
        clientSecret: clientSecret,
        smtpHost: smtpHost,
        smtpPort: intOf(env, "SMTP_PORT", 465),
        smtpSecure: boolOf(env, "SMTP_SECURE", true),
        smtpUser: smtpUser,
        smtpPassword: smtpPassword,
        smtpSignature: textOf(env, "SMTP_SIGNATURE", "Crying-Music"),
        dbFile: (dbRaw === "" ? resolve(serviceDir(), "..", "data", "cryingmusic.sqlite")
                              : resolve(serviceDir(), dbRaw)),
        codeTtlSeconds: intOf(env, "CODE_TTL_SECONDS", 600),
        sendCooldownSeconds: intOf(env, "SEND_COOLDOWN_SECONDS", 60),
        sendDailyLimit: intOf(env, "SEND_DAILY_LIMIT", 10),
        verifyMaxAttempts: intOf(env, "VERIFY_MAX_ATTEMPTS", 5),
        bodyLimitBytes: intOf(env, "BODY_LIMIT_BYTES", 8192)
    };
    return config;
}
