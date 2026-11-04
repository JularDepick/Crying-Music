/* 泣水音乐 验证码服务: 邮件投递
 * 作者: JularDepick (https://github.com/JularDepick)
 *
 * 只做一件事: 把六位验证码发到指定邮箱. 连接在启动时就建立好, 发送时复用,
 * 避免每封信重新握手; 发送失败原样抛出, 由路由层折成固定的错误码.
 */
import nodemailer from "nodemailer";
import type { Transporter } from "nodemailer";
import type { ApiConfig } from "./config.ts";

export class MailService {
    private readonly transport: Transporter;
    private readonly signature: string;
    private readonly from: string;

    constructor(config: ApiConfig) {
        this.signature = config.smtpSignature;
        this.from = '"泣水音乐" <' + config.smtpUser + ">";
        this.transport = nodemailer.createTransport({
            host: config.smtpHost,
            port: config.smtpPort,
            secure: config.smtpSecure,
            auth: {
                user: config.smtpUser,
                pass: config.smtpPassword
            }
        });
    }

    /* 发一封验证码邮件: 文本与 HTML 两版, 都没有图片与外链 */
    async sendCode(email: string, code: string, ttlMinutes: number): Promise<void> {
        const lines = [
            "您好,",
            "",
            "本次登录的验证码是 " + code + ", " + String(ttlMinutes) + " 分钟内有效.",
            "验证码只用于本人登录, 请勿转发给他人.",
            "若非本人操作, 忽略本邮件即可, 该邮箱不会被登录.",
            "",
            "-- " + this.signature
        ];
        const text = lines.join("\n");
        const html = [
            "<div style=\"font-family: 'Microsoft YaHei', Arial, sans-serif; font-size: 14px;"
                + " color: #1a1a1a; line-height: 1.7;\">",
            "<p>您好,</p>",
            "<p>本次登录的验证码是</p>",
            "<p style=\"font-size: 26px; font-weight: 700; letter-spacing: 6px; color: #00cc65;\">"
                + code + "</p>",
            "<p>" + String(ttlMinutes) + " 分钟内有效. 验证码只用于本人登录, 请勿转发给他人.</p>",
            "<p>若非本人操作, 忽略本邮件即可, 该邮箱不会被登录.</p>",
            "<p style=\"color: #888888;\">-- " + this.signature + "</p>",
            "</div>"
        ].join("");
        await this.transport.sendMail({
            from: this.from,
            to: email,
            subject: "[泣水音乐] 登录验证码",
            text: text,
            html: html
        });
    }

    /* 启动自检: 连接与账号可用时返回 true; 只用于打日志, 不影响服务上线 */
    async verifyConnection(): Promise<boolean> {
        try {
            await this.transport.verify();
            return true;
        } catch (error) {
            console.error("[邮件] SMTP 自检失败: " + String(error));
            return false;
        }
    }
}
