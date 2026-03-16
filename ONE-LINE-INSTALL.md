# RBT One-Line Installation Guide

## English Version

### Quick Install
```bash
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh)
```

### Interactive Installation with Menu System
```bash
# Install with full interactive menu system
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh)

# Install menu system only
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh) --menu-only

# Non-interactive installation
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh) --non-interactive
```

## Persian Version - نسخه فارسی

### نصب سریع فارسی
```bash
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-persian.sh)
```

### نصب تعاملی با منوی فارسی
```bash
# نصب کامل با منوی تعاملی فارسی
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-persian.sh)

# فقط نصب منوی سیستم
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-persian.sh) --menu-only

# نصب غیرتعاملی
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-persian.sh) --non-interactive
```

## Features - ویژگی‌ها

### Interactive Menu System - سیستم منوی تعاملی
- **Numbered Menu Options** - گزینه‌های منوی عددی
- **Input Validation** - اعتبارسنجی ورودی‌ها
- **Configuration Prompts** - درخواست‌های پیکربندی
- **Security Settings** - تنظیمات امنیتی
- **System Optimization** - بهینه‌سازی سیستم

### Installation Options - گزینه‌های نصب
1. **Quick Install** - نصب سریع با تنظیمات پیش‌فرض
2. **Custom Install** - نصب سفارشی با پیکربندی تعاملی
3. **Menu System Only** - فقط نصب سیستم منو
4. **Binary Only** - فقط نصب باینری
5. **System Optimization** - فقط بهینه‌سازی سیستم
6. **Uninstall** - حذف کامل RBT
7. **Update** - به‌روزرسانی RBT
8. **Interactive Menu** - اجرای منوی تعاملی

### Configuration Variables - متغیرهای پیکربندی

The installer will prompt for these variables during interactive installation:

#### Required Variables - متغیرهای الزامی:
- `ADMIN_USERNAME` - نام کاربری ادمین
- `ADMIN_PASSWORD` - رمز عبور ادمین
- `DASHBOARD_PORT` - پورت داشبورد
- `JWT_SECRET` - رمز JWT (به صورت خودکار تولید می‌شود)

#### Optional Variables - متغیرهای اختیاری:
- `HCAPTCHA_SITE_KEY` - کلید سایت hCaptcha
- `HCAPTCHA_SECRET_KEY` - کلید مخفی hCaptcha
- `SMTP_HOST` - هاست SMTP
- `SMTP_PORT` - پورت SMTP
- `SMTP_USER` - کاربر SMTP
- `SMTP_PASS` - رمز SMTP
- `NODE_ENV` - محیط Node.js

### System Requirements - نیازمندی‌های سیستم

#### Minimum Requirements - حداقل نیازمندی‌ها:
- Linux OS (Ubuntu, CentOS, Debian, etc.)
- 1GB RAM
- 100MB Disk Space
- Internet Connection

#### Recommended Requirements - نیازمندی‌های توصیه‌شده:
- 2GB+ RAM
- 1GB+ Disk Space
- Node.js 20.x
- Git
- curl, jq

### Security Features - ویژگی‌های امنیتی

- **Automatic JWT Secret Generation** - تولید خودکار رمز JWT
- **Strong Password Validation** - اعتبارسنجی رمز عبور قوی
- **Certificate Management** - مدیریت گواهینامه‌ها
- **System Hardening** - سخت‌گیری سیستم
- **Audit Logging** - لاگ حسابرسی

### Menu Navigation - ناوبری منو

```
========================================
     RBT Tunnel Orchestrator Installer    
========================================

Please select an option:

1) Quick Install (Default Settings)
2) Custom Install (Interactive Configuration)
3) Install Menu System Only
4) Install RBT Binary Only
5) System Optimization Only
6) Uninstall RBT
7) Update RBT
8) Run Interactive Menu
9) Advanced Options
0) Exit

Enter your choice [0-9]: 
```

### Advanced Options - گزینه‌های پیشرفته

- `--menu-only` - فقط نصب منوی سیستم
- `--skip-system-config` - از پیکربندی سیستم صرف‌نظر کنید
- `--non-interactive` - در حالت غیرتعاملی اجرا شود
- `--help` - نمایش راهنما

### Troubleshooting - عیب‌یابی

#### Common Issues - مشکلات رایج:

1. **Permission Denied** - خطای دسترسی:
   ```bash
   sudo bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh)
   ```

2. **Node.js Not Found** - Node.js پیدا نشد:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Binary Not Found** - باینری پیدا نشد:
   ```bash
   # Check if RBT is installed
   which rbt
   # Add to PATH if needed
   export PATH=$PATH:/usr/local/bin
   ```

### Manual Installation - نصب دستی

If automatic installation fails, you can install manually:

```bash
# 1. Install dependencies
sudo apt-get update
sudo apt-get install -y curl jq git nodejs

# 2. Download and install RBT
curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh | bash

# 3. Run interactive menu
rbt-menu
```

### Uninstallation - حذف

```bash
# Complete uninstallation
bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh)
# Select option 6 for uninstall

# Or manually:
sudo rm -f /usr/local/bin/rbt
sudo rm -rf /etc/rbt
sudo rm -f /usr/local/bin/rbt-menu
sudo rm -rf /opt/rbt-menu
```

### Support - پشتیبانی

For support and issues:
- GitHub Issues: https://github.com/EHSANKiNG/RBT/issues
- Documentation: https://github.com/EHSANKiNG/RBT/wiki
- Community: https://github.com/EHSANKiNG/RBT/discussions

### License - مجوز

This installer is part of the RBT project and follows the same license terms.

---

**Note**: The one-line installer includes all the interactive features, numbered menu system, configuration prompts, and security enhancements that were requested. Both English and Persian versions are available for better user experience.