/* 泣水音乐 验证码服务: 数据持久化
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * better-sqlite3 同步接口, 单进程写入, 不需要连接池; 每次访问都即时落盘,
 * 服务重启后冷却时间与已发验证码仍然有效.
 */
import DatabaseCtor from "better-sqlite3";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";

/* 一条待校验的验证码: 只存摘要, 不存明文 */
export interface CodeRecord {
    email: string;
    codeHash: string;
    expiresAt: number;
    sentAt: number;
    attempts: number;
}

/* 校验结果 */
export type VerifyOutcome = "ok" | "no_code" | "expired" | "attempts_exceeded" | "bad_code";

/* 一条登录状态秘钥: 由校验验证码成功后签发, 客户端后续凭它做用户操作 */
export interface SessionRecord {
    key: string;
    email: string;
    issuedAt: number;
    expiresAt: number;
    revokedAt: number;
}

export class ApiStore {
    private readonly db: InstanceType<typeof DatabaseCtor>;

    constructor(file: string) {
        mkdirSync(dirname(file), { recursive: true });
        this.db = new DatabaseCtor(file);
        this.db.pragma("journal_mode = WAL");
        this.db.pragma("foreign_keys = ON");
        this.migrate();
    }

    /* 建表: 验证码, 发送流水, 已验证过的邮箱, 登录流水, 登录状态秘钥与听歌流水 */
    private migrate(): void {
        this.db.exec([
            "CREATE TABLE IF NOT EXISTS codes (",
            "  email TEXT PRIMARY KEY,",
            "  code_hash TEXT NOT NULL,",
            "  expires_at INTEGER NOT NULL,",
            "  sent_at INTEGER NOT NULL,",
            "  attempts INTEGER NOT NULL DEFAULT 0",
            ");",
            "CREATE INDEX IF NOT EXISTS codes_expires ON codes(expires_at);",
            "CREATE TABLE IF NOT EXISTS send_log (",
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,",
            "  email TEXT NOT NULL,",
            "  at INTEGER NOT NULL",
            ");",
            "CREATE INDEX IF NOT EXISTS send_log_email ON send_log(email, at);",
            "CREATE TABLE IF NOT EXISTS users (",
            "  email TEXT PRIMARY KEY,",
            "  first_seen INTEGER NOT NULL,",
            "  last_seen INTEGER NOT NULL,",
            "  logins INTEGER NOT NULL DEFAULT 0",
            ");",
            "CREATE TABLE IF NOT EXISTS login_events (",
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,",
            "  email TEXT NOT NULL,",
            "  at INTEGER NOT NULL,",
            "  ip TEXT NOT NULL",
            ");",
            "CREATE INDEX IF NOT EXISTS login_events_email ON login_events(email, at);",
            "CREATE TABLE IF NOT EXISTS sessions (",
            "  key TEXT PRIMARY KEY,",
            "  email TEXT NOT NULL,",
            "  issued_at INTEGER NOT NULL,",
            "  expires_at INTEGER NOT NULL,",
            "  revoked_at INTEGER NOT NULL DEFAULT 0",
            ");",
            "CREATE INDEX IF NOT EXISTS sessions_email ON sessions(email, issued_at);",
            "CREATE TABLE IF NOT EXISTS listen_events (",
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,",
            "  email TEXT NOT NULL,",
            "  seconds INTEGER NOT NULL,",
            "  day TEXT NOT NULL,",
            "  at INTEGER NOT NULL",
            ");",
            "CREATE INDEX IF NOT EXISTS listen_events_email ON listen_events(email, day);"
        ].join("\n"));
    }

    /* 上一次发送到现在的间隔(毫秒): 没有记录时返回一个足够大的值 */
    sinceLastSendMs(email: string, now: number): number {
        const row = this.db.prepare("SELECT at FROM send_log WHERE email = ? ORDER BY at DESC LIMIT 1")
                          .get(email) as { at: number } | undefined;
        if (row === undefined) {
            return Number.MAX_SAFE_INTEGER;
        }
        return now - row.at;
    }

    /* 指定时刻之后的发送次数: 用于 24 小时上限 */
    sendCountSince(email: string, since: number): number {
        const row = this.db.prepare("SELECT COUNT(1) AS n FROM send_log WHERE email = ? AND at >= ?")
                          .get(email, since) as { n: number };
        return row.n;
    }

    /* 记录一次发送并写入新的验证码: 同一邮箱只保留最新一条, 旧验证码立即失效 */
    saveCode(record: CodeRecord): void {
        const tx = this.db.transaction((one: CodeRecord) => {
            this.db.prepare([
                "INSERT INTO codes (email, code_hash, expires_at, sent_at, attempts)",
                "VALUES (?, ?, ?, ?, 0)",
                "ON CONFLICT(email) DO UPDATE SET",
                "  code_hash = excluded.code_hash,",
                "  expires_at = excluded.expires_at,",
                "  sent_at = excluded.sent_at,",
                "  attempts = 0"
            ].join("\n")).run(one.email, one.codeHash, one.expiresAt, one.sentAt);
            this.db.prepare("INSERT INTO send_log (email, at) VALUES (?, ?)")
                   .run(one.email, one.sentAt);
        });
        tx(record);
    }

    /* 读一条验证码 */
    codeOf(email: string): CodeRecord | null {
        const row = this.db.prepare([
            "SELECT email, code_hash AS codeHash, expires_at AS expiresAt,",
            "       sent_at AS sentAt, attempts",
            "FROM codes WHERE email = ?"
        ].join("\n")).get(email) as CodeRecord | undefined;
        return (row === undefined ? null : row);
    }

    /* 失败次数加一 */
    bumpAttempts(email: string): void {
        this.db.prepare("UPDATE codes SET attempts = attempts + 1 WHERE email = ?").run(email);
    }

    /* 删除一条验证码: 校验成功, 过期或次数用尽都走这里 */
    dropCode(email: string): void {
        this.db.prepare("DELETE FROM codes WHERE email = ?").run(email);
    }

    /* 登录成功: 记邮箱首末次出现与登录流水 */
    recordLogin(email: string, at: number, ip: string): void {
        const tx = this.db.transaction(() => {
            this.db.prepare([
                "INSERT INTO users (email, first_seen, last_seen, logins)",
                "VALUES (?, ?, ?, 1)",
                "ON CONFLICT(email) DO UPDATE SET",
                "  last_seen = excluded.last_seen,",
                "  logins = logins + 1"
            ].join("\n")).run(email, at, at);
            this.db.prepare("INSERT INTO login_events (email, at, ip) VALUES (?, ?, ?)")
                   .run(email, at, ip);
        });
        tx();
    }

    /* 按邮箱取登录次数: 没有记录时返回 0 */
    loginCountOf(email: string): number {
        const row = this.db.prepare("SELECT logins FROM users WHERE email = ?")
                          .get(email) as { logins: number } | undefined;
        return (row === undefined ? 0 : row.logins);
    }

    /* 记入一条听歌流水: 秒数与日期一起存, 每日上限按日期汇总 */
    addListenSeconds(email: string, seconds: number, day: string, at: number): void {
        this.db.prepare("INSERT INTO listen_events (email, seconds, day, at) VALUES (?, ?, ?, ?)")
            .run(email, seconds, day, at);
    }

    /* 某邮箱某一天已累计的秒数: 用于每日上限判定 */
    listenSecondsOn(email: string, day: string): number {
        const row = this.db.prepare("SELECT COALESCE(SUM(seconds), 0) AS total FROM listen_events WHERE email = ? AND day = ?")
                          .get(email, day) as { total: number };
        return row.total;
    }

    /* 某邮箱累计的听歌秒数: 全部日期汇总 */
    listenSecondsTotal(email: string): number {
        const row = this.db.prepare("SELECT COALESCE(SUM(seconds), 0) AS total FROM listen_events WHERE email = ?")
                          .get(email) as { total: number };
        return row.total;
    }

    /* 某邮箱某一天的最后一条流水时刻: 供上报间隔判定, 没有流水时返回 0 */
    lastListenAt(email: string, day: string): number {
        const row = this.db.prepare("SELECT at FROM listen_events WHERE email = ? AND day = ? ORDER BY at DESC LIMIT 1")
                          .get(email, day) as { at: number } | undefined;
        return (row === undefined ? 0 : row.at);
    }

    /* 签发一条登录状态秘钥: 同一时刻每个邮箱只保留一条有效秘钥, 旧的先作废 */
    issueSession(record: SessionRecord): void {
        const tx = this.db.transaction((one: SessionRecord) => {
            this.db.prepare("UPDATE sessions SET revoked_at = ? WHERE email = ? AND revoked_at = 0")
                .run(one.issuedAt, one.email);
            this.db.prepare([
                "INSERT INTO sessions (key, email, issued_at, expires_at, revoked_at)",
                "VALUES (?, ?, ?, ?, 0)"
            ].join("\n")).run(one.key, one.email, one.issuedAt, one.expiresAt);
        });
        tx(record);
    }

    /* 按秘钥取一条登录状态记录: 不存在时返回 null */
    sessionOf(key: string): SessionRecord | null {
        const row = this.db.prepare([
            "SELECT key, email, issued_at AS issuedAt, expires_at AS expiresAt,",
            "       revoked_at AS revokedAt",
            "FROM sessions WHERE key = ?"
        ].join("\n")).get(key) as SessionRecord | undefined;
        return (row === undefined ? null : row);
    }

    /* 按邮箱取当前有效的登录状态记录: 没有时返回 null; 签发前先作废旧秘钥, 因此调用方不多 */

    /* 作废一条登录状态秘钥: 已作废或不存在时按成功处理 */
    revokeSession(key: string, at: number): boolean {
        const changed = this.db.prepare("UPDATE sessions SET revoked_at = ? WHERE key = ? AND revoked_at = 0")
                                .run(at, key).changes;
        return (changed > 0);
    }

    /* 续期一条登录状态秘钥: 只把到期时刻往后推, 有效期内才续得上 */
    renewSession(key: string, expiresAt: number): boolean {
        const changed = this.db.prepare("UPDATE sessions SET expires_at = ? WHERE key = ? AND revoked_at = 0")
                                .run(expiresAt, key).changes;
        return (changed > 0);
    }

    /* 清理过期数据: 过期一天的验证码, 两天前的发送流水, 撤销一天的秘钥与三十天前的听歌流水 */
    prune(now: number): void {
        this.db.prepare("DELETE FROM codes WHERE expires_at < ?").run(now - 86400000);
        this.db.prepare("DELETE FROM send_log WHERE at < ?").run(now - 172800000);
        this.db.prepare("DELETE FROM sessions WHERE expires_at < ? AND revoked_at > 0")
            .run(now - 86400000);
        this.db.prepare("DELETE FROM listen_events WHERE at < ?").run(now - 2592000000);
    }

    /* 关闭数据库 */
    close(): void {
        this.db.close();
    }
}
