# 泣水音乐验证码服务

Quick App 登录用的验证码服务. 只做两件事: 把六位验证码发到指定邮箱, 核对用户填回的验证码并在通过时签发一份带签名的登录凭证.

| 事项 | 技术 |
|:---:|:---:|
| 运行时 | Node.js 23.6 及以上(直接运行 TypeScript, 依赖类型擦除) |
| 语言 | TypeScript(仅使用可擦除语法, 不产出编译产物) |
| 数据库 | better-sqlite3, 单文件落盘 |
| 邮件 | nodemailer + SMTP |
| HTTP | node:http, 不引入 Web 框架 |

## 目录结构

```
api/
├── .env                  # 环境配置(不进版本库)
├── .env.example          # 环境配置样例
├── package.json          # 依赖与脚本
├── tsconfig.json         # 类型检查配置
├── README.md             # 本文档
└── src/
    ├── index.ts          # 入口: 路由, 鉴权, 关闭流程
    ├── config.ts         # .env 读取与默认值
    ├── db.ts             # 建表与数据读写
    ├── mailer.ts         # 邮件投递
    ├── code.ts           # 发送与校验两个接口
    ├── sign.ts           # 摘要与签名
    └── http.ts           # JSON 收发, 请求体上限, 客户端地址
```

## 接口

除健康检查外, 两个接口都要求 `POST` 与请求头 `X-Client-Secret`, 请求与响应一律 `application/json`.

### 发送验证码

`POST /api/code/send`

请求体:

```json
{ "email": "123456789@qq.com" }
```

成功响应(200):

```json
{ "ok": true, "email": "123456789@qq.com", "expiresIn": 600, "cooldown": 60,
  "message": "验证码已发送至 123456789@qq.com" }
```

### 校验验证码

`POST /api/code/verify`

请求体:

```json
{ "email": "123456789@qq.com", "code": "123456" }
```

成功响应(200):

```json
{ "ok": true, "email": "123456789@qq.com", "issuedAt": 1762264800000,
  "sign": "<64 位十六进制>", "message": "登录成功" }
```

登录凭证的签名是 `HMAC-SHA256(CLIENT_SECRET, "login|" + 邮箱 + "|" + 签发时刻)`, 客户端用同一个内置密钥复核后才落盘, 本地留存天数由客户端决定.

### 健康检查

`GET /api/health` 回 `{ "ok": true, "service": "crying-music-code", "time": 毫秒 }`, 不需要密钥.

## 错误码

失败响应固定为 `{ "ok": false, "code": "...", "message": "..." }`, 个别错误附带补充字段.

| HTTP | code | 含义 |
|:---:|:---:|:---:|
| 400 | bad_request | 请求体不是合法 JSON 或为空 |
| 400 | invalid_email | 邮箱格式不正确 |
| 400 | invalid_code | 验证码不是六位数字 |
| 400 | no_code | 没有待校验的验证码, 或已被新验证码覆盖 |
| 400 | expired | 验证码已过期 |
| 400 | attempts_exceeded | 失败次数用尽, 需要重新获取 |
| 400 | bad_code | 验证码不正确, 附带 remaining 剩余次数 |
| 401 | unauthorized | 客户端密钥无效 |
| 404 | bad_request | 接口不存在 |
| 405 | bad_request | 方法不是 POST |
| 429 | cooldown | 发送过于频繁, 附带 retryAfter 等待秒数 |
| 429 | daily_limit | 该邮箱当日获取次数已达上限 |
| 500 | internal_error | 服务内部错误 |
| 502 | smtp_failed | 邮件投递失败, 本次验证码已撤销 |

## 配置

全部配置项来自 `.env`, 必填项缺失时服务拒绝启动.

| 键 | 默认值 | 说明 |
|:---:|:---:|:---:|
| API_HOST | 0.0.0.0 | 监听地址; 留空表示不指定地址, 由系统按默认的双栈地址监听 |
| API_PORT | 26714 | 监听端口 |
| CLIENT_SECRET | 无(必填) | 客户端内置密钥, 同时用于请求鉴权与登录凭证签名 |
| DB_FILE | ../data/cryingmusic.sqlite | 数据库文件, 相对路径按服务目录解析 |
| CODE_TTL_SECONDS | 600 | 验证码有效期(秒) |
| SEND_COOLDOWN_SECONDS | 60 | 同一邮箱两次发送的最短间隔(秒) |
| SEND_DAILY_LIMIT | 10 | 同一邮箱 24 小时内最多发送次数 |
| VERIFY_MAX_ATTEMPTS | 5 | 同一验证码允许的失败次数 |
| BODY_LIMIT_BYTES | 8192 | 请求体上限(字节) |
| SMTP_HOST | 无(必填) | SMTP 服务器地址 |
| SMTP_PORT | 465 | SMTP 端口 |
| SMTP_SECURE | true | 是否直接使用 TLS |
| SMTP_USER | 无(必填) | 发件邮箱 |
| SMTP_PASSWORD | 无(必填) | 发件邮箱的授权码或密码 |
| SMTP_SIGNATURE | Crying-Music | 邮件尾部签名 |

## 运行

依赖用 pnpm 管理; better-sqlite3 是原生模块, 需要允许它执行安装脚本, 因此 `pnpm-workspace.yaml` 里放行了 `allowBuilds`.

```bash
pnpm install
pnpm run start     # 前台运行
pnpm run dev       # 文件变更自动重启
pnpm run typecheck # 只做类型检查, 不产出编译产物
```

包管理器把 store 放在用户目录时, 沙箱化的开发环境可能拒绝写入; 必要时用 `pnpm install --store-dir ./.pnpm-store` 把 store 放进服务目录.

## 数据

- `codes`: 待校验的验证码, 每个邮箱只保留最新一条, 只存摘要
- `send_log`: 发送流水, 用于冷却与每日上限
- `users`: 验证通过的邮箱与首末次出现, 登录次数
- `login_events`: 每次登录的时间与来源地址

过期一天的验证码与两天前的发送流水由服务每十分钟清理一次.

## 安全说明

- 验证码只存摘要, 比对走常量时间比较
- 接口只认请求头里的客户端密钥, 密钥不出现在 URL 与日志里
- 邮件投递失败时撤销本次验证码, 不让冷却时间白白占掉
- 登录凭证的签名可离线复核, 但密钥随客户端分发, 它的作用限于发现本地文件被改动, 不是服务端的权限凭证
