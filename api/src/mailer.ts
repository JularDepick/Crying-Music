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

    /* 发一封验证码邮件: 文本与 HTML 两版, 都没有图片与外链.
     * HTML 按邮件客户端的通用口径写: 表格布局加内联样式, 不引外部 CSS, 不用 flex 与 grid;
     * 600 宽的白卡片落在浅灰底上, 验证码单独成块并用等宽字体, 其余文字只用黑白灰三档,
     * 正文段落每段一句, 收尾的次要信息不与验证码抢注意力. */
    async sendCode(email: string, code: string, ttlMinutes: number): Promise<void> {
        const ttlText = String(ttlMinutes) + " 分钟内有效, 请勿转发给他人.";
        const text = [
            "泣水音乐 · 登录验证码",
            "",
            "你正在登录泣水音乐, 请在登录页输入下面的验证码:",
            "",
            "    " + code,
            "",
            "验证码 " + ttlText,
            "若非本人操作, 忽略本邮件即可, 该邮箱不会被登录.",
            "",
            "-- " + this.signature,
            "本邮件由系统自动发送, 请勿直接回复"
        ].join("\n");
        const html = [
            "<!DOCTYPE html>",
            "<html lang=\"zh-CN\">",
            "<head>",
            "<meta charset=\"utf-8\" />",
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
            "<meta name=\"color-scheme\" content=\"light dark\" />",
            "<meta name=\"supported-color-schemes\" content=\"light dark\" />",
            "<title>登录验证码</title>",
            "</head>",
            "<body style=\"margin:0;padding:0;background:#f4f4f5;\">",
            /* 预标题: 收件箱列表里先露出验证码, 正文里不显示 */
            "<div style=\"display:none;max-height:0;overflow:hidden;opacity:0;\">泣水音乐登录验证码: "
                + code + "</div>",
            "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\""
                + " style=\"background:#f4f4f5;\">",
            "<tr><td align=\"center\" style=\"padding:32px 16px;\">",
            "<table role=\"presentation\" width=\"600\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\""
                + " style=\"width:100%;max-width:600px;background:#ffffff;border-radius:10px;\">",
            "<tr><td style=\"padding:40px 40px 32px 40px;font-family:'Microsoft YaHei','PingFang SC',Arial,sans-serif;"
                + " color:#111111;\">",
            "<div style=\"font-size:13px;letter-spacing:2px;color:#8a8a8a;\">泣水音乐</div>",
            "<div style=\"font-size:22px;font-weight:700;line-height:1.3;margin:18px 0 0 0;\">登录验证码</div>",
            "<div style=\"font-size:15px;line-height:1.7;color:#4a4a4a;margin:10px 0 0 0;\">"
                + "你正在登录泣水音乐, 请在登录页输入下面的验证码.</div>",
            "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\""
                + " style=\"margin:26px 0 0 0;\">",
            "<tr><td align=\"center\" style=\"background:#f6f6f6;border-radius:8px;padding:22px 0 22px 8px;"
                + "font-family:Consolas,Menlo,'Courier New',monospace;font-size:30px;font-weight:700;"
                + "letter-spacing:8px;color:#111111;\">" + code + "</td></tr>",
            "</table>",
            "<div style=\"font-size:14px;line-height:1.7;color:#6b7280;margin:22px 0 0 0;\">验证码 "
                + ttlText + "</div>",
            "<div style=\"height:1px;line-height:1px;font-size:0;background:#eeeeee;margin:26px 0 0 0;\">&nbsp;</div>",
            "<div style=\"font-size:13px;line-height:1.7;color:#8a8a8a;margin:18px 0 0 0;\">"
                + "若非本人操作, 忽略本邮件即可, 该邮箱不会被登录.</div>",
            "</td></tr>",
            "</table>",
            "<div style=\"font-size:12px;line-height:1.6;color:#a3a3a3;margin:18px 0 0 0;\">"
                + "本邮件由系统自动发送, 请勿直接回复</div>",
            "</td></tr>",
            "</table>",
            "</body>",
            "</html>"
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
