# ⚙️ راهنمای پیکربندی و یکپارچه‌سازی مقاومت در برابر سانسور برای RBT

## 📋 معرفی

این سند راهنمای عملی برای پیکربندی و یکپارچه‌سازی قابلیت‌های مقاومت در برابر سانسور در پروژه RBT ارائه می‌دهد. تمرکز بر روی سناریوهای واقعی مانند قطع اینترنت توسط کشورهایی مانند ایران است.

---

## 🚀 نصب سریع و آسان

### 📦 روش 1: نصب خودکار (توصیه شده)

```bash
# دانلود و اجرای اسکریپت نصب هوشمند
cd /home/user/webapp && curl -fsSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-censorship-resistance.sh | bash

# یا با wget
wget -qO- https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-censorship-resistance.sh | bash
```

### 🛠️ روش 2: نصب دستی

```bash
# 1. کلون کردن مخزن
git clone https://github.com/EHSANKiNG/RBT.git
cd RBT

# 2. نصب dependencyها
cargo install --path crates/censorship-resistance
cargo install --path crates/advanced-dns
cargo install --path crates/mesh-network

# 3. کپی فایل‌های پیکربندی
cp config/advanced-dns.toml.example config/advanced-dns.toml
cp config/mesh-network.toml.example config/mesh-network.toml
cp config/censorship-resistance.toml.example config/censorship-resistance.toml

# 4. پیکربندی سریع
./scripts/quick-config.sh
```

---

## ⚙️ پیکربندی برای سناریوهای مختلف

### 🌍 سناریو 1: ایران - قطع کامل اینترنت بین‌المللی

#### مشخصات وضعیت:
- ✅ اینترنت بین‌المللی کاملاً قطع شده
- ✅ فقط اینترنت ملی (اینترنت داخلی) در دسترس است
- ✅ DNS کاملاً سانسور شده
- ✅ حتی ICMP (ping) هم مسدود شده
- ✅ VPN و پروکسی‌های معمول کار نمی‌کنند

#### پیکربندی توصیه شده:

```toml
# config/extreme-censorship-iran.toml
[general]
mode = "extreme_resistance"
locale = "iran"
censorship_level = "total_blackout"

# DNS پیشرفته - مهم‌ترین بخش
[advanced_dns]
enabled = true
primary_method = "mesh_steganography"
backup_methods = ["quantum_dot", "covert_channels"]

# سرورهای DNS over HTTPS - استفاده از آی‌پی مستقیم
[[advanced_dns.doh_servers]]
url = "https://1.1.1.1/dns-query"
ips = ["1.1.1.1", "1.0.0.1"]
description = "Cloudflare - Direct IP"
type = "encrypted"

[[advanced_dns.doh_servers]]
url = "https://8.8.8.8/dns-query"
ips = ["8.8.8.8", "8.8.4.4"]
description = "Google - Direct IP"
type = "encrypted"

# شبکه Mesh - حیاتی برای شرایط اضطراری
[mesh_network]
enabled = true
mode = "emergency"
discovery_method = "bluetooth_wifi_direct"

[[mesh_network.local_nodes]]
name = "neighbor1"
interface = "bluetooth"
mac_address = "XX:XX:XX:XX:XX:XX"
distance = "close"

[[mesh_network.local_nodes]]
name = "neighbor2"
interface = "wifi_direct"
ssid = "RBT_Mesh_Emergency"
password = "secure_mesh_2024"

# سیستم ماهواره‌ای - تنها راه دسترسی به اینترنت واقعی
[satellite]
enabled = true
primary_system = "starlink_covert"
backup_systems = ["vsat_hidden", "custom_satellite"]

[satellite.starlink]
terminal_id = "STRLNK_IR_001"
frequency_masking = true
anti_jamming = true
covert_operation = true

# استگانوگرافی برای پنهان‌سازی ترافیک
[steganography]
enabled = true
priority = "high"
carrier_types = ["images", "videos", "audio", "game_traffic"]
adaptive_hiding = true

# کانال‌های پنهان برای ارسال داده
[covert_channels]
enabled = true
methods = ["dns_tunneling", "icmp_tunneling", "http_covert", "email_steganography"]

# تنظیمات مربوط به ایران
[iran_specific]
# لیست دامنه‌هایی که حتماً باید در دسترس باشند
critical_domains = [
    "google.com",
    "youtube.com",
    "twitter.com",
    "telegram.org",
    "signal.org",
    "torproject.org",
]

# روش‌های سانسور رایج در ایران
censorship_methods = ["dpi", "dns_poisoning", "bgp_blocking", "throttling"]

# ISPهای ایران که باید دور زده شوند
blocked_isps = ["MCI", "Irancell", "Shatel", "ParsOnline", "Asiatech"]
```

### 🔧 اسکریپت پیکربندی خودکار برای ایران

```bash
#!/bin/bash
# scripts/configure-iran-resistance.sh

echo "🔧 پیکربندی RBT برای مقاومت در برابر سانسور شدید ایران..."

# بررسی سیستم عامل
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "❌ سیستم عامل پشتیبانی نمی‌شود"
    exit 1
fi

# ایجاد فهرست پیکربندی ایران
mkdir -p config/iran
cat > config/iran/extreme-censorship.toml << 'EOF'
# پیکربندی برای مقاومت در برابر سانسور شدید در ایران
[general]
mode = "extreme_resistance"
locale = "iran"
censorship_level = "total_blackout"

[advanced_dns]
enabled = true
primary_method = "mesh_steganography"
backup_methods = ["quantum_dot", "covert_channels"]

[mesh_network]
enabled = true
mode = "emergency"
discovery_method = "bluetooth_wifi_direct"

[satellite]
enabled = true
primary_system = "starlink_covert"

[steganography]
enabled = true
priority = "high"
carrier_types = ["images", "videos", "audio"]
EOF

# دانلود سرورهای DNS سفارشی برای ایران
echo "📥 دانلود سرورهای DNS مقاوم برای ایران..."
curl -s https://raw.githubusercontent.com/EHSANKiNG/RBT/main/configs/iran/dns-servers.json > config/iran/dns-servers.json

# پیکربندی شبکه Mesh
echo "📡 پیکربندی شبکه Mesh..."
cat > config/iran/mesh-config.sh << 'EOF'
#!/bin/bash
# فعال‌سازی Bluetooth
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

# فعال‌سازی WiFi Direct
sudo modprobe wl18xx
sudo iw dev wlan0 interface add wlp2p0 type __p2pdev

# تنظیمات firewall برای Mesh
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 8080 -j ACCEPT
EOF

chmod +x config/iran/mesh-config.sh

# پیکربندی ماهواره‌ای
echo "🛰️ پیکربندی سیستم ماهواره‌ای..."
cat > config/iran/satellite-setup.sh << 'EOF'
#!/bin/bash
# نصب ابزارهای ماهواره‌ای
sudo apt-get update
sudo apt-get install -y starlink-tools vsat-utils

# تنظیمات Starlink
echo "starlink-terminal enable" | sudo tee /etc/starlink/config

# تنظیمات VSAT
echo "vsat-modem auto-detect" | sudo tee /etc/vsat/config
EOF

chmod +x config/iran/satellite-setup.sh

echo "✅ پیکربندی ایران کامل شد!"
echo "📋 مراحل بعدی:"
echo "1. اجرای ./config/iran/mesh-config.sh برای تنظیم Mesh"
echo "2. اجرای ./config/iran/satellite-setup.sh برای تنظیم ماهواره"
echo "3. ویرایش config/iran/extreme-censorship.toml برای تنظیمات دلخواه"
```

---

## 🛰️ سناریو 2: کشورهای همسایه - محدودیت‌های منطقه‌ای

### پیکربندی برای کشورهای همسایه ایران:

```toml
# config/neighboring-countries.toml
[general]
mode = "regional_resistance"
region = "mena"  # Middle East and North Africa
censorship_level = "moderate"

[advanced_dns]
enabled = true
primary_method = "doh_encrypted"
backup_methods = ["dot_quantum", "mesh_steganography"]

# استفاده از سرورهای منطقه‌ای
[[advanced_dns.regional_servers]]
country = "turkey"
servers = ["turkey-dns1.rbtdns.net", "turkey-dns2.rbtdns.net"]

[[advanced_dns.regional_servers]]
country = "armenia"
servers = ["armenia-dns1.rbtdns.net", "armenia-dns2.rbtdns.net"]

[[advanced_dns.regional_servers]]
country = "azerbaijan"
servers = ["azeri-dns1.rbtdns.net", "azeri-dns2.rbtdns.net"]

[mesh_network]
enabled = true
mode = "regional"
cross_border = true

[[mesh_network.border_nodes]]
country1 = "iran"
country2 = "turkey"
interface = "long_range_wifi"
distance = "50km"

[satellite]
enabled = true
primary_system = "regional_vsat"
backup_systems = ["starlink", "custom_satellite"]

# تنظیمات خاص منطقه
[regional_settings]
# زبان‌های محلی
languages = ["fa", "tr", "ar", "ru"]

# منطقه زمانی
timezone = "asia_tehran"

# ارز محلی
currency = "irr"
```

---

## 📱 سناریو 3: دستگاه‌های موبایل - محدودیت‌های موبایلی

```toml
# config/mobile-censorship.toml
[general]
mode = "mobile_resistance"
device_type = "mobile"
battery_optimized = true

[mobile_dns]
enabled = true
low_power_mode = true
quick_fallback = true

# تنظیمات مخصوص موبایل
[mobile_settings]
# استفاده از اینترنت موبایل برای Mesh
mobile_data_mesh = true

# صرفه‌جویی در باتری
battery_optimization = true
background_sync = false

# اندازه小包 برای موبایل
packet_size = "small"
connection_timeout = 15

# ویژگی‌های خاص موبایل
[mobile_features]
# استفاده از WiFi hotspot برای Mesh
wifi_hotspot_mesh = true

# استفاده از Bluetooth Low Energy
ble_mesh = true

# استفاده از NFC برای ارتباط اولیه
nfc_handshake = true
```

---

## 🚀 راه‌اندازی سریع

### ⚡ روش 1: استفاده از Wizard

```bash
# اجرای wizard تعاملی
cd /home/user/webapp && ./scripts/resistance-wizard.sh

# Wizard از چند سوال ساده می‌پرسد:
echo "🌍 در کدام کشور هستید؟ (iran/turkey/iraq/افغانستان/سایر)"
echo "📱 نوع دستگاه شما چیست؟ (desktop/mobile/server)"
echo "🔧 سطح فنی شما چقدر است؟ (beginner/intermediate/expert)"
echo "💰 آیا به اینترنت ماهواره‌ای دسترسی دارید؟ (yes/no/maybe)"
```

### 🔧 روش 2: استفاده از پیکربندی آماده

```bash
# کپی کردن پیکربندی مناسب
cp config/presets/iran-extreme.toml config/active-config.toml

# ویرایش سریع
nano config/active-config.toml

# اعمال تغییرات
./scripts/apply-config.sh config/active-config.toml
```

---

## 📊 نظارت و عیب‌یابی

### 🔍 ابزار نظارت بر عملکرد

```bash
# نصب ابزار نظارت
cargo install --path crates/monitoring-tools

# اجرای نظارت بر DNS
rbt-monitor-dns --config config/active-config.toml --duration 3600

# اجرای نظارت بر Mesh
rbt-monitor-mesh --discover --continuous

# اجرای نظارت بر سانسور
rbt-detect-censorship --analyze --report
```

### 📋 گزارش‌گیری خودکار

```toml
# config/monitoring.toml
[monitoring]
enabled = true
report_interval = 3600  # هر ساعت
alert_threshold = 0.8  # اگر 80٪ روش‌ها شکست بخورند

[reporting]
format = "json"
destination = "logs/performance-reports/"
include_metrics = ["dns_success_rate", "mesh_connectivity", "censorship_detection"]

[alerts]
email = "admin@your-domain.com"
telegram = "@your_bot"
webhook = "https://your-webhook-endpoint.com"
```

---

## 🛠️ عیب‌یابی مشکلات رایج

### ❌ مشکل 1: DNS هنوز هم کار نمی‌کند

```bash
# بررسی وضعیت DNS
dig +short google.com @1.1.1.1

# اگر بالا کار نکرد:
# 1. استفاده از Mesh network
./scripts/test-mesh-connection.sh

# 2. استفاده از استگانوگرافی
./scripts/test-steganography-dns.sh

# 3. استفاده از ماهواره
./scripts/test-satellite-connection.sh
```

### ❌ مشکل 2: Mesh network گره‌هایی پیدا نمی‌کند

```bash
# بررسی سخت‌افزار
sudo systemctl status bluetooth
sudo iwconfig

# اسکن دستی
sudo hcitool scan
sudo iw dev wlan0 scan | grep SSID

# تست ارتباط مستقیم
./scripts/test-direct-connection.sh
```

### ❌ مشکل 3: ماهواره وصل نمی‌شود

```bash
# بررسی تجهیزات
lsusb | grep -i starlink
sudo dmesg | grep -i satellite

# تست سیگنال
./scripts/test-satellite-signal.sh

# تنظیم مجدد مودم
./scripts/reset-satellite-modem.sh
```

---

## 🔐 امنیت و مخفی‌سازی

### 🛡️ تنظیمات امنیتی پیشرفته

```toml
# config/security-advanced.toml
[security]
# سطح امنیتی
security_level = "maximum"

# رمزنگاری
encryption = "post_quantum"
key_rotation = 3600  # هر ساعت

# مخفی‌سازی
obfuscation = "adaptive"
steganography = "aggressive"

# ضد شناسایی
anti_detection = true
anti_forensics = true

[security.keys]
# کلیدهای رمزنگاری
private_key = "..."
public_key = "..."
rotation_enabled = true
backup_keys = 3

[security.opsec]
# عملیات امنیتی
remove_logs = true
fake_traffic = true
time_jitter = true
route_randomization = true
```

### 🕵️ روش‌های مخفی‌سازی

```bash
# فعال‌سازی مخفی‌سازی پیشرفته
./scripts/enable-stealth-mode.sh

# تنظیمات مخفی‌سازی ترافیک
./scripts/configure-traffic-masking.sh

# تنظیمات مخفی‌سازی زمان‌بندی
./scripts/configure-timing-obfuscation.sh
```

---

## 📚 منابع و مستندات اضافی

### 📖 منابع فارسی
- [راهنمای مقاومت در برابر سانسور اینترنت](https://github.com/EHSANKiNG/RBT/wiki/FA-Censorship-Resistance)
- [پیکربندی برای کاربران ایرانی](https://github.com/EHSANKiNG/RBT/wiki/FA-Iran-Config)
- [عیب‌یابی مشکلات رایج](https://github.com/EHSANKiNG/RBT/wiki/FA-Troubleshooting)

### 🎥 ویدیوهای آموزشی
- [آموزش نصب RBT برای مقاومت در برابر سانسور](https://youtube.com/watch?v=rbt-censorship-resistance)
- [پیکربندی شبکه Mesh برای شرایط اضطراری](https://youtube.com/watch?v=rbt-mesh-emergency)
- [استفاده از ماهواره برای عبور از سانسور](https://youtube.com/watch?v=rbt-satellite-bypass)

### 💬 پشتیبانی جامعه
- [گروه تلگرام پشتیبانی فارسی](https://t.me/RBT_Persian_Support)
- [فروم گیت‌هاب برای گزارش مشکلات](https://github.com/EHSANKiNG/RBT/discussions)
- [ایمیل پشتیبانی فنی](mailto:support@rbt-project.com)

---

## 📞 تماس اضطراری

در صورت بروز مشکل حاد یا نیاز به کمک فوری:

📧 **ایمیل اضطراری:** emergency@rbt-project.com
📱 **تلفن پشتیبانی:** +1-XXX-XXX-XXXX
💬 **تلگرام اضطراری:** @RBT_Emergency

---

**🔒 این سند فقط برای مقابله با سانسور اینترنت و حفظ آزادی دسترسی به اطلاعات طراحی شده است. استفاده از آن فقط برای اهداف قانونی و اخلاقی مجاز است.**