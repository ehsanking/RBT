# RBT: 隧道编排平台

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/Rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![Version](https://img.shields.io/badge/Version-0.0.2-blue.svg)](https://github.com/EHSANKiNG/RBT)

RBT 是一个以工程和研究为核心的服务器到服务器隧道平台，旨在用于合法的基础设施管理、受控实验和技术评估。

RBT 通过利用现代协议 (QUIC) 和内核级优化 (零拷贝 TCP)，在丢包率高的网络中表现出色。

## 🛠️ 技术栈
- **核心**: Rust (高性能、内存安全、异步监督器)
- **前端**: React, Tailwind CSS, Lucide Icons
- **后端**: Node.js/Express, WebSocket 用于实时遥测
- **隧道**: QUIC (UDP 数据报), Linux `splice()` (零拷贝 TCP)

## 📥 安装
您可以使用我们的自动安装脚本安装 RBT 及其所有依赖项。该脚本会检测您的操作系统，安装必要的系统依赖项（如 `rustup`, `node`, `npm`），并设置 RBT 环境。

```bash
curl -fsSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install.sh | bash
```

*注意：此脚本需要 root 权限才能安装系统依赖项。*

## ⚙️ 配置与环境变量
安装后，请在 `.env` 文件中配置以下环境变量：

| 变量 | 描述 |
| :--- | :--- |
| `HCAPTCHA_SITE_KEY` | 来自 [hCaptcha](https://www.hcaptcha.com/) 的站点密钥。 |
| `HCAPTCHA_SECRET` | 来自 [hCaptcha](https://www.hcaptcha.com/) 的密钥。 |
| `JWT_SECRET` | 用于签名身份验证令牌的强随机字符串。 **在此生成：** [jwtsecrets.com](https://jwtsecrets.com/#generator)。 |
| `SMTP_HOST` | 用于通知的 SMTP 服务器主机名。 |
| `SMTP_PORT` | SMTP 服务器端口（例如 587）。 |
| `SMTP_USER` | SMTP 用户名。 |
| `SMTP_PASS` | SMTP 密码。 |
| `NOTIFICATION_EMAIL` | 接收警报的电子邮件地址。 |

## 🚀 交互式 CLI
对于交互式体验，请使用内置的 UI 菜单：
```bash
npx rbt-ui
```
*(需要安装 Node.js)*

## 📖 隧道机制
- **Anti-DPI 混淆**: AEAD 风格的流量混淆，掩盖数据包头，防止 DPI 系统检测。
- **动态端口跳跃**: 使用基于 TOTP 的同步机制来规避端口封锁。
- **QUIC UDP 数据报**: 消除 UDP 流量的队头阻塞。
- **零拷贝 TCP**: 集成 Linux 内核级 `splice()`，实现最大吞吐量和最小延迟。

## 💻 CLI 参考
`rbt` 命令行界面是管理隧道的主要工具。

| 命令 | 描述 |
| :--- | :--- |
| `rbt link-add --name <name> --listen <addr> --target <addr> --proto <tcp\|udp>` | 创建新隧道。 |
| `rbt apply` | 应用配置并启动监督进程。 |
| `rbt logs -f` | 流式传输实时日志。 |
| `rbt stats --json` | 获取 JSON 格式的流量统计信息。 |

## ⚖️ 免责声明
本项目仅用于合法研究、授权的基础设施管理和受控测试。严禁将其用于掩盖恶意活动、规避监控或绕过访问控制。作者 (EHSANKiNG) 明确拒绝将其用于隐蔽操作或 DPI 规避。
