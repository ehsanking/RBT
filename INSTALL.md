# 🚀 راهنمای نصب و راه‌اندازی RBT

## 📋 فهرست مطالب

- [📥 نصب سریع](#-نصب-سریع)
- [🔧 نصب پیشرفته](#-نصب-پیشرفته)
- [⚙️ پیکربندی اولیه](#-پیکربندی-اولیه)
- [🎯 راه‌اندازی اولیه](#-راه‌اندازی-اولیه)
- [🔍 عیب‌یابی](#-عیبیابی)

---

## 📥 نصب سریع

### 🚀 روش توصیه شده - نصب یک‌خطی

```bash
# نصب کامل با اسکریپت هوشمند
curl -fsSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh | bash

# یا با wget
wget -qO- https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh | bash
```

### 📦 روش دستی - مرحله به مرحله

```bash
# 1. دریافت کد منبع
git clone https://github.com/EHSANKiNG/RBT.git
cd RBT

# 2. نصب وابستگی‌ها
npm install

# 3. اجرای نصب کننده تعاملی
npm run rbt-install
```

---

## 🔧 نصب پیشرفته

### 🎯 گزینه‌های نصب سفارشی

```bash
# نصب با حداقل وابستگی‌ها
bash install-complete-enhanced.sh --minimal

# نصب با حداکثر امنیت
bash install-complete-enhanced.sh --security-hardened

# نصب با نظارت کامل
bash install-complete-enhanced.sh --monitoring-full

# نصب بدون تعامل (غیرفعال)
bash install-complete-enhanced.sh --non-interactive
```

### ⚙️ پارامترهای پیشرفته

| پارامتر | توضیحات | مثال |
|---------|---------|------|
| `--install-path` | مسیر نصب سفارشی | `--install-path /opt/rbt` |
| `--config-path` | مسیر فایل پیکربندی | `--config-path /etc/rbt/config.toml` |
| `--log-level` | سطح لاگ‌گیری | `--log-level debug` |
| `--skip-deps` | نادیده گرفتن وابستگی‌ها | `--skip-deps` |
| `--force` | نصب اجباری | `--force` |

---

## ⚙️ پیکربندی اولیه

### 📝 ایجاد فایل‌های پیکربندی

```bash
# 1. کپی فایل نمونه پیکربندی
cp config.example.toml config.toml

# 2. کپی فایل نمونه محیطی
cp .env.example .env

# 3. ویرایش فایل‌ها با ویرایشگر دلخواه
nano config.toml
nano .env
```

### 🔑 متغیرهای ضروری محیطی

```bash
# فایل .env - متغیرهای ضروری
JWT_SECRET="your-super-secure-secret-min-32-characters-long"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="secure-complex-password-123!"
DASHBOARD_PORT="3000"

# اختیاری - hCaptcha
HCAPTCHA_SITE_KEY="your-hcaptcha-site-key"
HCAPTCHA_SECRET="your-hcaptcha-secret-key"

# اختیاری - اطلاع‌رسانی ایمیل
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-specific-password"
NOTIFICATION_EMAIL="alerts@your-domain.com"
```

### 📋 پیکربندی اصلی (config.toml)

```toml
# RBT Configuration File
# https://github.com/EHSANKiNG/RBT

[server]
host = "0.0.0.0"
port = 3000
workers = 4
max_connections = 1000

[security]
enable_ssl = true
auto_renew = true
cert_path = "./ssl/cert.pem"
key_path = "./ssl/key.pem"

[tunnel]
protocol = "quic"  # quic, tcp, udp
enable_dpi_bypass = true
port_hopping = true
congestion_control = "bbr"

[monitoring]
enabled = true
metrics_port = 9090
retention_days = 30
alert_thresholds = true

[logging]
level = "info"  # debug, info, warn, error
file = "./logs/rbt.log"
max_size = "100MB"
max_files = 10
```

---

## 🎯 راه‌اندازی اولیه

### 🚀 شروع سریع

```bash
# 1. راه‌اندازی سرویس
npm run rbt-menu

# 2. انتخاب گزینه "شروع سریع"
# 3. پیکربندی خودکار
# 4. شروع سرویس
```

### 🔧 راه‌اندازی دستی

```bash
# 1. اعتبارسنجی پیکربندی
npx tsx scripts/config-manager.ts validate

# 2. بهینه‌سازی سیستم
npx tsx scripts/config-manager.ts optimize

# 3. شروع نظارت
npx tsx scripts/monitor.ts start

# 4. ایجاد تونل نمونه
rbt link-add --name test --listen 0.0.0.0:8080 --target 127.0.0.1:80 --proto tcp

# 5. اعمال پیکربندی
rbt apply
```

---

## 🔍 عیب‌یابی

### 🚨 مشکلات رایج و راه‌حل‌ها

#### ❌ خطای "Permission denied"

```bash
# راه‌حل: اعطای دسترسی اجرایی
chmod +x install-complete-enhanced.sh
sudo ./install-complete-enhanced.sh
```

#### ❌ خطای "Port already in use"

```bash
# بررسی پورت‌های در حال استفاده
sudo netstat -tulpn | grep :3000

# تغییر پورت در فایل .env
DASHBOARD_PORT="3001"
```

#### ❌ خطای "Missing dependencies"

```bash
# نصب وابستگی‌های سیستم
sudo apt update && sudo apt install -y curl jq nodejs npm

# یا برای CentOS/RHEL
sudo yum install -y curl jq nodejs npm
```

#### ❌ خطای "Invalid JWT secret"

```bash
# ایجاد JWT secret ایمن
openssl rand -base64 32

# یا استفاده از ابزار آنلاین
# https://jwtsecrets.com/#generator
```

### 📋 بررسی وضعیت سیستم

```bash
# بررسی وضعیت کلی
systemctl status rbt

# بررسی لاگ‌های سیستم
journalctl -u rbt -f

# بررسی اتصالات شبکه
ss -tulpn | grep rbt

# بررسی منابع سیستم
top -p $(pgrep rbt)
```

### 🛠️ ابزارهای عیب‌یابی داخلی

```bash
# اجرای عیب‌یاب خودکار
npx tsx scripts/troubleshoot.ts diagnose

# بررسی سلامت شبکه
npx tsx scripts/troubleshoot.ts network-test

# بررسی امنیت
npx tsx scripts/troubleshoot.ts security-check

# گزارش کامل
npx tsx scripts/troubleshoot.ts full-report
```

---

## 📞 پشتیبانی

### 🌐 منابع آنلاین

- 📖 [مستندات کامل](./README.md)
- 🔧 [راهنمای پیکربندی](./CONFIG.md)
- 🛡️ [راهنمای امنیتی](./SECURITY.md)
- 🐛 [گزارش مشکلات](https://github.com/EHSANKiNG/RBT/issues)

### 💬 انجمن‌ها

- [GitHub Discussions](https://github.com/EHSANKiNG/RBT/discussions)
- [Telegram Channel](https://t.me/RBT_Tunnel)
- [Discord Server](https://discord.gg/rbt-tunnel)

---

<div align="center">

**🔒 ساخته شده با ❤️ برای جامعه امنیت سایبری و شبکه**

</div>