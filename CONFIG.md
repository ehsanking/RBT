# ⚙️ راهنمای جامع پیکربندی RBT

## 📋 فهرست مطالب

- [🎯 مقدمه](#-مقدمه)
- [📋 پیکربندی پایه](#-پیکربندی-پایه)
- [🔧 پیکربندی پیشرفته](#-پیکربندی-پیشرفته)
- [🛡️ پیکربندی امنیتی](#-پیکربندی-امنیتی)
- [📊 پیکربندی نظارت](#-پیکربندی-نظارت)
- [🚀 پیکربندی عملکرد](#-پیکربندی-عملکرد)
- [🌐 پیکربندی شبکه](#-پیکربندی-شبکه)
- [🔍 اعتبارسنجی و بهینه‌سازی](#-اعتبارسنجی-و-بهینهسازی)

---

## 🎯 مقدمه

این راهنما تمام جنبه‌های پیکربندی RBT را پوشش می‌دهد - از تنظیمات ساده تا پیکربندی‌های پیچیده سازمانی. هر بخش با مثال‌های عملی و توضیحات کامل ارائه شده است.

---

## 📋 پیکربندی پایه

### 📝 ساختار فایل‌های پیکربندی

```
RBT/
├── config.toml          # فایل پیکربندی اصلی
├── .env                 # متغیرهای محیطی
├── ssl/                 # گواهینامه‌های SSL
│   ├── cert.pem
│   └── key.pem
├── logs/                # فایل‌های لاگ
└── backup/              # پشتیبان‌ها
```

### ⚙️ فایل پیکربندی اصلی (config.toml)

```toml
# RBT Configuration File v2.0
# https://github.com/EHSANKiNG/RBT

# === BASIC CONFIGURATION ===
[server]
# آدرس و پورت سرور
host = "0.0.0.0"                    # گوش دادن به تمام interfaces
port = 3000                          # پورت پیش‌فرض داشبورد
workers = 4                          # تعداد workerها
max_connections = 1000                # حداکثر اتصالات همزمان

# === LOGGING CONFIGURATION ===
[logging]
level = "info"                       # levels: debug, info, warn, error, fatal
file = "./logs/rbt.log"              # مسیر فایل لاگ
max_size = "100MB"                   # حداکثر اندازه فایل
max_files = 10                        # حداکثر تعداد فایل‌های لاگ
format = "json"                      # فرمت: json, text

# === DATABASE CONFIGURATION ===
[database]
type = "sqlite"                      # types: sqlite, mysql, postgresql
path = "./data/rbt.db"               # برای SQLite
# host = "localhost"                   # برای MySQL/PostgreSQL
# port = 3306                        # برای MySQL/PostgreSQL
# username = "rbt_user"               # برای MySQL/PostgreSQL
# password = "secure_password"        # برای MySQL/PostgreSQL
# database = "rbt_db"                 # برای MySQL/PostgreSQL

# === BACKUP CONFIGURATION ===
[backup]
enabled = true
interval = "24h"                     # فاصله بکاپ‌گیری
retention = "30d"                    # مدت نگهداری بکاپ‌ها
path = "./backup"                    # مسیر ذخیره بکاپ‌ها
compress = true                      # فشرده‌سازی بکاپ‌ها
```

### 🔑 متغیرهای محیطی (.env)

```bash
# === CRITICAL SECURITY VARIABLES ===
# ⚠️ این متغیرها باید حتماً تغییر کنند

# JWT Configuration
JWT_SECRET="minimum-32-characters-ultra-secure-random-string-here"
JWT_EXPIRES_IN="24h"
JWT_ALGORITHM="HS256"

# Admin Credentials
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="complex-password-123!@#"
ADMIN_EMAIL="admin@your-domain.com"

# === OPTIONAL SECURITY FEATURES ===

# hCaptcha (Anti-Bot Protection)
HCAPTCHA_SITE_KEY="your-hcaptcha-site-key-here"
HCAPTCHA_SECRET="your-hcaptcha-secret-key-here"
HCAPTCHA_THRESHOLD="0.5"

# Email Notifications
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_SECURE="true"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-specific-password"
NOTIFICATION_EMAIL="alerts@your-domain.com"

# === ADVANCED CONFIGURATION ===

# Server Configuration
NODE_ENV="production"
PORT="3000"
HOST="0.0.0.0"

# Session Configuration
SESSION_SECRET="another-32-character-secret-string"
SESSION_TIMEOUT="1800000"  # 30 minutes in milliseconds

# Rate Limiting
RATE_LIMIT_WINDOW="15"
RATE_LIMIT_MAX="100"

# CORS Configuration
CORS_ORIGIN="https://your-domain.com"
CORS_CREDENTIALS="true"
```

---

## 🔧 پیکربندی پیشرفته

### 🚀 پیکربندی تونل‌ها

```toml
# === TUNNEL CONFIGURATION ===
[tunnel]
# پروتکل تونل‌زنی
protocol = "quic"                      # quic, tcp, udp, http, https

# بهینه‌سازی‌های پیشرفته
enable_dpi_bypass = true             # عبور از DPI
port_hopping = true                  # تغییر خودکار پورت
congestion_control = "bbr"            # الگوریتم کنترل ازدحام
zero_copy = true                      # Zero-copy optimization

# تنظیمات QUIC (در صورت انتخاب QUIC)
[tunnel.quic]
max_idle_timeout = "30s"
keep_alive_interval = "10s"
max_concurrent_streams = 100
congestion_controller = "bbr"

# تنظیمات TCP (در صورت انتخاب TCP)
[tunnel.tcp]
no_delay = true
keep_alive = true
reuse_address = true
backlog = 511

# تنظیمات UDP (در صورت انتخاب UDP)
[tunnel.udp]
buffer_size = "1MB"
promiscuous = false
broadcast = false
```

### 📊 پیکربندی نظارت و مانیتورینگ

```toml
# === MONITORING CONFIGURATION ===
[monitoring]
enabled = true
metrics_port = 9090                  # پورت Prometheus metrics
health_check_interval = "30s"         # فاصله بررسی سلامت
retention_days = 30                    # مدت نگهداری داده‌ها

# تنظیمات هشدار
[monitoring.alerts]
enabled = true
email_alerts = true
webhook_alerts = true
sms_alerts = false                     # نیاز به پیکربندی SMS

# آستانه‌های هشدار
[monitoring.thresholds]
cpu_warning = 70                       # درصد CPU برای هشدار زرد
cpu_critical = 85                      # درصد CPU برای هشدار قرمز
memory_warning = 80                    # درصد حافظه برای هشدار زرد
memory_critical = 90                   # درصد حافظه برای هشدار قرمز
disk_warning = 75                      # درصد دیسک برای هشدار زرد
disk_critical = 85                     # درصد دیسک برای هشدار قرمز

# تنظیمات Prometheus
[monitoring.prometheus]
enabled = true
port = 9090
path = "/metrics"
scrape_interval = "15s"

# تنظیمات Grafana
[monitoring.grafana]
enabled = false
url = "http://localhost:3001"
api_key = "your-grafana-api-key"
dashboard_id = "rbt-dashboard"
```

### 🔄 پیکربندی بکاپ‌گیری

```toml
# === BACKUP CONFIGURATION ===
[backup]
enabled = true
schedule = "0 2 * * *"                  # Cron expression - ساعت 2 شب روزانه
retention_policy = "30d"               # نگهداری برای 30 روز
compress = true                        # فشرده‌سازی بکاپ‌ها
encrypt = true                         # رمزگذاری بکاپ‌ها

# مقصد بکاپ
[backup.destination]
type = "local"                         # local, s3, ftp, sftp
path = "./backup"
# برای S3:
# bucket = "rbt-backups"
# region = "us-west-2"
# access_key = "your-access-key"
# secret_key = "your-secret-key"

# چه چیزهایی بکاپ گرفته شود
[backup.include]
config = true
database = true
logs = false                           # لاگ‌ها معمولاً نیازی به بکاپ ندارند
ssl_certs = true
custom_files = ["./custom", "./uploads"]

# تنظیمات اعلان بکاپ
[backup.notifications]
enabled = true
on_success = true
on_failure = true
email = "admin@your-domain.com"
```

---

## 🛡️ پیکربندی امنیتی

### 🔐 تنظیمات احراز هویت

```toml
# === AUTHENTICATION CONFIGURATION ===
[auth]
method = "jwt"                         # jwt, session, oauth, saml
jwt_secret = "${JWT_SECRET}"           # از متغیر محیطی بخوان
jwt_expires_in = "24h"
jwt_algorithm = "HS256"

# تنظیمات OAuth (در صورت استفاده)
[auth.oauth]
enabled = false
providers = ["google", "github"]

[auth.oauth.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"
callback_url = "https://your-domain.com/auth/google/callback"

[auth.oauth.github]
client_id = "your-github-client-id"
client_secret = "your-github-client-secret"
callback_url = "https://your-domain.com/auth/github/callback"

# تنظیمات SAML (در صورت استفاده)
[auth.saml]
enabled = false
entry_point = "https://your-idp.com/saml/sso"
cert = "./saml/cert.pem"
issuer = "rbt-tunnel"
```

### 🛡️ تنظیمات امنیتی پیشرفته

```toml
# === SECURITY CONFIGURATION ===
[security]
level = "high"                         # low, medium, high, maximum
auto_hardening = true                  # سخت‌گیری خودکار
enable_firewall = true                # فعال‌سازی فایروال داخلی

# تنظیمات SSL/TLS
[security.ssl]
enabled = true
protocols = ["TLSv1.3", "TLSv1.2"]     # فقط پروتکل‌های امن
cipher_suites = [
    "TLS_AES_256_GCM_SHA384",
    "TLS_CHACHA20_POLY1305_SHA256"
]
cert_path = "./ssl/cert.pem"
key_path = "./ssl/key.pem"
ca_path = "./ssl/ca.pem"

# تنظیمات rate limiting
[security.rate_limit]
enabled = true
window_ms = 900000                   # 15 دقیقه
max = 100                              # حداکثر 100 درخواست
message = "Too many requests from this IP"

# تنظیمات CORS
[security.cors]
enabled = true
origin = ["https://your-domain.com"]
methods = ["GET", "POST", "PUT", "DELETE"]
headers = ["Content-Type", "Authorization"]
credentials = true
max_age = 86400                        # 24 ساعت

# تنظیمات CSP (Content Security Policy)
[security.csp]
enabled = true
policy = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
```

---

## 📊 پیکربندی نظارت

### 📈 تنظیمات لاگ‌گیری

```toml
# === LOGGING CONFIGURATION ===
[logging]
level = "info"                         # debug, info, warn, error, fatal
format = "json"                        # json, text
enable_colors = true                   # رنگ در خروجی ترمینال

# لاگ‌گیری فایل
[logging.file]
enabled = true
path = "./logs/rbt.log"
max_size = "100MB"
max_files = 10
compress = true                        # فشرده‌سازی فایل‌های قدیمی

# لاگ‌گیری سیستم
[logging.syslog]
enabled = false
facility = "local0"
tag = "rbt-tunnel"

# لاگ‌گیری remote (اختیاری)
[logging.remote]
enabled = false
url = "https://your-log-server.com/logs"
token = "your-log-token"
buffer_size = 1000
flush_interval = "30s"
```

### 📊 تنظیمات متریکس و مانیتورینگ

```toml
# === METRICS CONFIGURATION ===
[metrics]
enabled = true
interval = "15s"                       # فاصله جمع‌آوری متریکس
retention = "7d"                       # مدت نگهداری

# متریکس سیستم
[metrics.system]
cpu = true
memory = true
disk = true
network = true
processes = true

# متریکس برنامه
[metrics.application]
requests = true
response_time = true
error_rate = true
active_connections = true

# متریکس تجاری
[metrics.business]
tunnels_active = true
tunnels_total = true
bandwidth_usage = true
unique_users = true
```

---

## 🚀 پیکربندی عملکرد

### ⚡ تنظیمات عملکرد

```toml
# === PERFORMANCE CONFIGURATION ===
[performance]
# تنظیمات کلی
worker_processes = "auto"               # auto یا عدد خاص
worker_connections = 1024
worker_timeout = "30s"

# تنظیمات حافظه
cache_size = "100MB"
cache_ttl = "1h"
memory_limit = "1GB"

# تنظیمات شبکه
keep_alive_timeout = "75s"
client_max_body_size = "10MB"
request_timeout = "30s"

# تنظیمات پیشرفته
[performance.advanced]
enable_compression = true               # فشرده‌سازی پاسخ‌ها
compression_level = 6                  # سطح فشرده‌سازی (1-9)
enable_caching = true                  # کش‌گیری پاسخ‌ها
cache_duration = "5m"

# تنظیمات load balancing
[performance.load_balancing]
enabled = false
algorithm = "round_robin"             # round_robin, least_conn, ip_hash
health_check = true
fail_timeout = "30s"
```

### 🔄 تنظیمات کش

```toml
# === CACHE CONFIGURATION ===
[cache]
enabled = true
type = "memory"                        # memory, redis, memcached
ttl = "1h"                             # زمان زندگی کش
max_size = "100MB"

# تنظیمات Redis (در صورت استفاده)
[cache.redis]
host = "localhost"
port = 6379
password = ""
database = 0
max_connections = 10

# تنظیمات Memcached (در صورت استفاده)
[cache.memcached]
servers = ["localhost:11211"]
max_connections = 10
```

---

## 🌐 پیکربندی شبکه

### 🌐 تنظیمات شبکه

```toml
# === NETWORK CONFIGURATION ===
[network]
# تنظیمات پایه
bind_ip = "0.0.0.0"                    # آدرس IP برای bind کردن
bind_port = 3000                     # پورت اصلی
traffic_class = "AF41"                  # QoS traffic class

# تنظیمات DNS
dns_servers = ["8.8.8.8", "8.8.4.4"]   # سرورهای DNS
dns_timeout = "5s"
dns_cache_ttl = "5m"

# تنظیمات پروکسی
[proxy]
enabled = false
type = "http"                          # http, socks5
host = "proxy.your-domain.com"
port = 8080
username = "proxy-user"
password = "proxy-pass"
```

### 🔗 تنظیمات تونل‌های پیشرفته

```toml
# === ADVANCED TUNNEL CONFIGURATION ===
[tunnels]
# تنظیمات عمومی
max_tunnels = 50                       # حداکثر تعداد تونل‌ها
max_bandwidth = "1Gbps"                 # حداکثر پهنای باند
max_clients = 1000                      # حداکثر کلاینت‌ها

# تنظیمات امنیتی تونل
[tunnels.security]
encryption = "AES-256-GCM"
authentication = "SHA-256"
key_exchange = "ECDH-P384"
perfect_forward_secrecy = true

# تنظیمات بهینه‌سازی
[tunnels.optimization]
enable_compression = true
compression_algorithm = "gzip"
enable_caching = true
cache_size = "10MB"

# تنظیمات عبور از DPI
[tunnels.dpi_bypass]
enabled = true
method = "obfuscation"                 # obfuscation, fragmentation, encryption
obfuscation_level = "high"
pattern_randomization = true
```

---

## 🔍 اعتبارسنجی و بهینه‌سازی

### ✅ ابزار اعتبارسنجی

```bash
# اعتبارسنجی پیکربندی
npx tsx scripts/config-manager.ts validate

# اعتبارسنجی امنیتی
npx tsx scripts/config-manager.ts validate --security

# اعتبارسنجی عملکرد
npx tsx scripts/config-manager.ts validate --performance

# گزارش کامل
npx tsx scripts/config-manager.ts report
```

### ⚡ ابزار بهینه‌سازی

```bash
# بهینه‌سازی خودکار
npx tsx scripts/config-manager.ts optimize

# بهینه‌سازی برای عملکرد بالا
npx tsx scripts/config-manager.ts optimize --performance

# بهینه‌سازی برای امنیت بالا
npx tsx scripts/config-manager.ts optimize --security

# بهینه‌سازی برای مصرف منابع پایین
npx tsx scripts/config-manager.ts optimize --minimal
```

### 📊 تحلیل و گزارش‌گیری

```bash
# تحلیل عملکرد
npx tsx scripts/config-manager.ts analyze --performance

# تحلیل امنیتی
npx tsx scripts/config-manager.ts analyze --security

# مقایسه پیکربندی‌ها
npx tsx scripts/config-manager.ts compare config1.toml config2.toml

# پیشنهادات بهبود
npx tsx scripts/config-manager.ts suggest-improvements
```

---

## 🎯 نکات و ترفندها

### 💡 نکات پیکربندی

1. **همیشه از متغیرهای محیطی برای اطلاعات حساس استفاده کنید**
2. **پیکربندی را در محیط تست قبل از production تست کنید**
3. **از کش‌گیری برای بهبود عملکرد استفاده کنید**
4. **لاگ‌گیری را فعال نگه دارید اما مراقب اندازه فایل‌ها باشید**
5. **بکاپ‌گیری خودکار را پیکربندی کنید**

### ⚠️ هشدارهای امنیتی

- هرگز اطلاعات حساس را در فایل‌های پیکربندی hardcode نکنید
- از SSL/TLS برای تمام communications استفاده کنید
- Rate limiting را برای جلوگیری از حملات DDoS فعال کنید
- به‌روزرسانی‌های امنیتی را به‌موقع انجام دهید
- از مکانیزم‌های نظارت برای تشخیص مشکلات استفاده کنید

---

<div align="center">

**⚙️ پیکربندی صحیح، پایه‌گذار عملکرد و امنیت عالی!**

</div>