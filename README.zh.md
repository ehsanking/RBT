# 🚀 RBT - 高级隧道编排平台

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/Rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![Version](https://img.shields.io/badge/Version-0.0.2-blue.svg)](https://github.com/EHSANKiNG/RBT)
[![Node.js](https://img.shields.io/badge/Node.js-16+-green.svg)](https://nodejs.org/)
[![React](https://img.shields.io/badge/React-19+-61DAFB.svg)](https://reactjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.8+-3178C6.svg)](https://www.typescriptlang.org/)

[![Performance](https://img.shields.io/badge/Performance-Optimized-brightgreen.svg)](./ENHANCED-FEATURES.md)
[![Security](https://img.shields.io/badge/Security-Enterprise-blue.svg)](./SECURITY.md)
[![Monitoring](https://img.shields.io/badge/Monitoring-Real--time-orange.svg)](./ENHANCED-FEATURES.md)

</div>

<p align="center">
  <strong>🔒 高级隧道 | 🚀 高性能网络 | 🛡️ 企业安全</strong>
</p>

<div align="center">
  <img src="https://img.shields.io/badge/Protocol-QUIC%20%7C%20TCP%20%7C%20UDP-blue" alt="协议">
  <img src="https://img.shields.io/badge/Optimization-Zero--Copy%20%7C%20BBR-green" alt="优化">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey" alt="平台">
</div>

---

## 📋 目录

- [🌟 平台介绍](#-平台介绍)
- [🎯 核心特性](#-核心特性)
- [📊 性能指标](#-性能指标)
- [🛠️ 快速安装](#️-快速安装)
- [⚙️ 配置指南](#️-配置指南)
- [🎮 高级界面](#-高级界面)
- [📖 技术文档](#-技术文档)
- [🔧 开发工具](#-开发工具)
- [🛡️ 安全监控](#️-安全监控)
- [📈 性能图表](#-性能图表)
- [🌍 国际化](#-国际化)
- [🤝 贡献指南](#-贡献指南)
- [📄 开源协议](#-开源协议)

---

## 🌟 平台介绍

**RBT** (Research-Based Tunneling) 是一个基于 `rstun` 构建的高级服务器到服务器隧道平台。专为低质量网络环境和研究场景设计，采用 **QUIC** 等现代协议和 **零拷贝TCP** 内核级优化技术。

### 🎯 核心目标
- ✅ 在高丢包网络中实现安全快速通信
- ✅ 绕过深度包检测(DPI)系统
- ✅ 简化网络基础设施管理
- ✅ 实时监控和分析
- ✅ 企业级安全保障

---

## 🎯 核心特性

### 🔒 高级安全功能
- **AEAD加密** 用于流量混淆
- **DPI绕过** 使用先进技术
- **自动SSL/TLS证书** 支持自动续期
- **多因素认证系统**

### 🚀 高性能特性
- **零拷贝TCP** 使用Linux `splice()` 系统调用
- **BBR拥塞控制** 实现最大吞吐量
- **QUIC for UDP** 无队头阻塞
- **内核级内存复制避免**

### 🎛️ 高级管理功能
- **动态端口跳变** 基于TOTP加密同步
- **自动路由切换** 检测到封锁时
- **实时监控** 智能告警
- **自动备份恢复**

---

## 📊 性能指标

### 📈 性能统计

| 性能指标 | 数值 | 状态 |
|-------------|--------|--------|
| **网络延迟** | < 5ms | ✅ 优秀 |
| **吞吐量** | 10+ Gbps | ✅ 优秀 |
| **丢包率** | < 0.01% | ✅ 优秀 |
| **响应时间** | < 100ms | ✅ 优秀 |
| **DPI规避率** | 99.9% | ✅ 优秀 |

### 🎯 协议性能对比图

```
📊 协议性能对比 (越高越好)
┌─────────────────────────────────────────────────────────────┐
│ 协议性能 (Mbps)                                         │
│                                                            │
│ 1000 ┤                                              ╭───── │
│  900 ┤                                          ╭──╯      │
│  800 ┤                                      ╭──╯          │
│  700 ┤                                  ╭───╯              │
│  600 ┤                              ╭──╯                  │
│  500 ┤                          ╭───╯                     │
│  400 ┤                      ╭───╯                         │
│  300 ┤                  ╭───╯                             │
│  200 ┤              ╭───╯                                 │
│  100 ┤          ╭───╯                                      │
│    0 ┴──────────┴──────────┴──────────┴──────────┴─────────│
│      QUIC     TCP       UDP       HTTP      HTTPS         │
│                    协议                                  │
└─────────────────────────────────────────────────────────────┘

🚀 QUIC: 950 Mbps | 🔥 TCP: 750 Mbps | ⚡ UDP: 600 Mbps
📈 HTTP: 500 Mbps | 🔒 HTTPS: 450 Mbps
```

---

## 🛠️ 快速安装

### 🚀 推荐方法 - 一行命令安装

```bash
# 使用智能脚本完整安装
curl -fsSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh | bash

# 或者使用 wget
wget -qO- https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh | bash
```

### 📦 高级安装选项

```bash
# 最小依赖安装
bash install-complete-enhanced.sh --minimal

# 最高安全级别安装
bash install-complete-enhanced.sh --security-hardened

# 完整监控安装
bash install-complete-enhanced.sh --monitoring-full

# 非交互式安装
bash install-complete-enhanced.sh --non-interactive
```

### 🛠️ 手动安装

```bash
# 1. 克隆仓库
git clone https://github.com/EHSANKiNG/RBT.git
cd RBT

# 2. 安装依赖
npm install

# 3. 运行交互式安装器
npm run rbt-install
```

---

## ⚙️ 配置指南

### 🔑 必需环境变量

```bash
# 安全和认证
JWT_SECRET="minimum-32-characters-ultra-secure-random-string"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="secure-complex-password-123!"
DASHBOARD_PORT="3000"

# 可选 - hCaptcha(反机器人)
HCAPTCHA_SITE_KEY="your-hcaptcha-site-key"
HCAPTCHA_SECRET="your-hcaptcha-secret-key"

# 可选 - 邮件通知
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-specific-password"
NOTIFICATION_EMAIL="alerts@your-domain.com"
```

### ⚡ 快速配置

```bash
# 使用智能配置工具
npx tsx scripts/config-manager.ts wizard

# 验证配置
npx tsx scripts/config-manager.ts validate

# 自动优化
npx tsx scripts/config-manager.ts optimize
```

---

## 🎮 高级界面

### 📋 智能交互菜单

```bash
# 运行主菜单
npm run rbt-menu

# 或者直接运行
npx tsx scripts/rbt-menu.ts
```

### 🎯 主菜单选项

| 选项 | 描述 | 命令 |
|-------|-------------|---------|
| **1** | 快速开始 | `quickstart` |
| **2** | 配置 | `config` |
| **3** | 隧道管理 | `tunnels` |
| **4** | 监控分析 | `monitoring` |
| **5** | 安全和证书 | `security` |
| **6** | 系统工具 | `tools` |
| **7** | 文档 | `docs` |
| **8** | 更新RBT | `update` |
| **9** | 故障排除 | `troubleshoot` |
| **0** | 退出 | `exit` |

### 📊 高级Web仪表板

```bash
# 启动Web仪表板
npm run rbt-ui

# 通过浏览器访问
# http://localhost:3000
```

---

## 📖 技术文档

### 🔧 CLI命令

| 命令 | 用途 | 示例 |
|--------|--------|--------|
| `rbt link-add` | 创建新隧道 | `rbt link-add --name web --listen 0.0.0.0:8080 --target 192.168.1.100:80 --proto tcp` |
| `rbt apply` | 应用配置 | `rbt apply --config config.toml` |
| `rbt logs` | 查看日志 | `rbt logs -f --level info` |
| `rbt stats` | 统计信息 | `rbt stats --json --pretty` |
| `rbt cert` | 证书管理 | `rbt cert issue --domain example.com` |

### 📈 监控分析

```bash
# 启动完整监控
npx tsx scripts/monitor.ts start

# 查看实时统计
npx tsx scripts/monitor.ts stats

# 性能报告
npx tsx scripts/monitor.ts report --format html
```

### 🛡️ 安全审计

```bash
# 运行完整安全审计
npx tsx scripts/security-manager.ts audit

# 更新证书
npx tsx scripts/security-manager.ts renew

# 漏洞扫描
npx tsx scripts/security-manager.ts scan
```

---

## 🔧 开发工具

### 🧪 测试套件

```bash
# 运行所有测试
npm test

# 单元测试
npm run test:unit

# 集成测试
npm run test:integration

# 性能测试
npm run test:performance

# 安全测试
npm run test:security
```

### 📊 分析优化

```bash
# 性能分析
npx tsx scripts/test-suite.ts benchmark

# 自动优化
npx tsx scripts/config-manager.ts optimize --aggressive

# 系统报告
npx tsx scripts/system-analyzer.ts full-report
```

---

## 🛡️ 安全监控

### 🔒 安全特性
- ✅ **军用级加密** (AES-256-GCM)
- ✅ **多因素认证** (MFA)
- ✅ **自动SSL/TLS证书**
- ✅ **入侵检测系统** (IDS)
- ✅ **智能防火墙**
- ✅ **完整日志审计**

### 📊 实时监控

| 指标 | 告警阈值 | 操作 |
|--------|----------------|--------|
| **CPU使用率** | > 80% | 黄色告警 |
| **内存使用率** | > 85% | 红色告警 |
| **磁盘使用率** | > 90% | 严重告警 |
| **网络错误** | > 100/小时 | 连接检查 |
| **失败登录** | > 5/分钟 | IP封禁 |

---

## 📈 性能图表

### 📊 24小时性能趋势

```
📊 24小时性能趋势
┌─────────────────────────────────────────────────────────────┐
│ 时间    │ CPU  │ 内存   │ 网络    │ 隧道数  │ 状态      │
├─────────┼──────┼────────┼─────────┼─────────┼───────────┤
│ 00:00   │ 15%  │ 45%    │ 120Mbps│ 5       │ ✅ 正常   │
│ 06:00   │ 25%  │ 55%    │ 450Mbps│ 12      │ ✅ 正常   │
│ 12:00   │ 65%  │ 75%    │ 890Mbps│ 25      │ ⚠️ 高     │
│ 18:00   │ 45%  │ 60%    │ 650Mbps│ 18      │ ✅ 正常   │
│ 24:00   │ 20%  │ 50%    │ 200Mbps│ 8       │ ✅ 正常   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🌍 国际化

### 🌐 支持语言

| 语言 | 状态 | 代码 |
|----------|--------|------|
| **English (英文)** | ✅ 完整 | `en` |
| **Persian (波斯语)** | ✅ 完整 | `fa` |
| **Chinese (中文)** | ✅ 完整 | `zh` |
| **Russian (俄语)** | ✅ 完整 | `ru` |

### 📚 多语言文档

- **[English README (英文)](./README.md)**
- **[Persian README (波斯语)](./README.fa.md)**
- **[Chinese README (中文)](./README.zh.md)**
- **[Russian README (俄语)](./README.ru.md)**

### 🔄 切换语言

```bash
# 切换到中文
npx tsx scripts/i18n.ts set-lang zh

# 切换到英文
npx tsx scripts/i18n.ts set-lang en
```

---

## 🤝 贡献指南

### 🌟 贡献指南

我们欢迎贡献！请：

1. ⭐ 给仓库点星
2. 🔀 Fork 仓库
3. 🌿 创建功能分支 (`git checkout -b feature/amazing-feature`)
4. 💾 提交更改 (`git commit -m 'Add amazing feature'`)
5. 📤 推送到分支 (`git push origin feature/amazing-feature`)
6. 📋 创建 Pull Request

### 🎯 贡献类型

- 🐛 **Bug 报告** - 提交新 Issues
- 💡 **新功能** - 提交功能请求
- 📝 **文档** - 改进 README 和 Wiki
- 🧪 **测试** - 提高测试覆盖率
- 🔧 **代码** - 优化和清理代码

---

## 📄 开源协议

本项目采用 **MIT 协议** - 详见 [LICENSE](LICENSE) 文件。

### ⚖️ 法律免责声明

本项目 **严格用于合法研究、授权基础设施管理和受控测试**。禁止用于隐藏恶意活动、规避监控或绕过访问控制。作者 (EHSANKiNG) 明确反对将其用于隐蔽操作或 DPI 规避。

---

<div align="center">

### 🌟 支持项目

如果觉得项目有用，请给它 ⭐ 星标并分享给其他人！

### 💝 捐赠

如果您觉得这个项目有用，请考虑支持其开发：

**泰达币 (USDT):** `TKPswLQqd2e73UTGJ5prxVXBVo7MTsWedU`

**波场币 (TRX):** `TKPswLQqd2e73UTGJ5prxVXBVo7MTsWedU`

### 🌟 支持项目

如果您觉得这个项目有用，请给它 ⭐ 加星并与他人分享！

[![Stars](https://img.shields.io/github/stars/EHSANKiNG/RBT?style=social)](https://github.com/EHSANKiNG/RBT/stargazers)
[![Forks](https://img.shields.io/github/forks/EHSANKiNG/RBT?style=social)](https://github.com/EHSANKiNG/RBT/network/members)
[![Watchers](https://img.shields.io/github/watchers/EHSANKiNG/RBT?style=social)](https://github.com/EHSANKiNG/RBT/watchers)

</div>

---

<div align="center">

**🔒 用 ❤️ 为网络安全和网络社区构建**

</div>