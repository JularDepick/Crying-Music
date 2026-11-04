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

export class ApiStore {
    private readonly db: InstanceType<typeof DatabaseCtor>;

    constructor(file: string) {
        mkdirSync(dirname(file), { recursive: true });
        this.db = new DatabaseCtor(file);
        this.db.pragma("journal_mode = WAL");
        this.db.pragma("foreign_keys = ON");
        this.migrate();
    }

    /* 建表: 验证码, 发送流水, 已验证过的邮箱与登录流水 */
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
            "CREATE INDEX IF NOT EXISTS login_events_email ON login_events(email, at);"
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

    /* 清理过期数据: 过期一天的验证码与两天前的发送流水, 定期调用即可 */
    prune(now: number): void {
        this.db.prepare("DELETE FROM codes WHERE expires_at < ?").run(now - 86400000);
        this.db.prepare("DELETE FROM send_log WHERE at < ?").run(now - 172800000);
    }

    /* 关闭数据库 */
    close(): void {
        this.db.close();
    }
}
