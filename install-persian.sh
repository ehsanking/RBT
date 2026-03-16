#!/bin/bash

# RBT نصب کننده یک‌خطی فارسی با منوی تعاملی
# دستور نصب یک‌خطی: bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-persian.sh)

set -e

# رنگ‌های خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# متغیرهای پیکربندی
INSTALL_PATH="/usr/local/bin/rbt"
REPO="EHSANKiNG/RBT"
TEMP_DIR="/tmp/rbt-install"
INTERACTIVE_MODE=true
MENU_ONLY=false
SKIP_SYSTEM_CONFIG=false

# تابع نمایش وضعیت فارسی
print_status_fa() {
    echo -e "${BLUE}[اطلاعات]${NC} $1"
}

print_success_fa() {
    echo -e "${GREEN}[موفق]${NC} $1"
}

print_warning_fa() {
    echo -e "${YELLOW}[هشدار]${NC} $1"
}

print_error_fa() {
    echo -e "${RED}[خطا]${NC} $1"
}

print_header_fa() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}     RBT نصب کننده تونل اورکستراتور    ${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo
}

# بررسی دسترسی روت
check_root_fa() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
        print_warning_fa "شما به عنوان روت اجرا می‌کنید. این به دلایل امنیتی توصیه نمی‌شود."
        read -p "آیا ادامه می‌دهید؟ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        SUDO="sudo"
        print_status_fa "استفاده از sudo برای عملیات ممتاز."
    fi
}

# تشخیص مدیر بسته
detect_pkg_manager_fa() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_INSTALL="$SUDO apt-get install -y"
        PKG_UPDATE="$SUDO apt-get update"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_INSTALL="$SUDO yum install -y"
        PKG_UPDATE="$SUDO yum makecache"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="$SUDO dnf install -y"
        PKG_UPDATE="$SUDO dnf makecache"
    else
        print_error_fa "مدیر بسته پشتیبانی نشده. لطفاً وابستگی‌ها را به صورت دستی نصب کنید."
        exit 1
    fi
    print_status_fa "مدیر بسته شناسایی شده: $PKG_MANAGER"
}

# نصب وابستگی‌ها
install_dependencies_fa() {
    print_status_fa "در حال نصب وابستگی‌های سیستم..."
    
    if ! command -v curl &> /dev/null; then
        $PKG_UPDATE
        $PKG_INSTALL curl
    fi
    
    if ! command -v jq &> /dev/null; then
        $PKG_INSTALL jq
    fi
    
    if ! command -v git &> /dev/null; then
        $PKG_INSTALL git
    fi
    
    if ! command -v node &> /dev/null; then
        print_status_fa "در حال نصب Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO -E bash -
        $PKG_INSTALL nodejs
    fi
    
    print_success_fa "وابستگی‌ها با موفقیت نصب شدند."
}

# بهینه‌سازی سیستم
optimize_system_fa() {
    if [[ "$SKIP_SYSTEM_CONFIG" == "true" ]]; then
        print_warning_fa "بهینه‌سازی سیستم به درخواست شما نادیده گرفته می‌شود."
        return
    fi
    
    print_status_fa "بهینه‌سازی تنظیمات سیستم برای RBT..."
    
    # ایجاد پیکربندی sysctl
    $SUDO tee /etc/sysctl.d/99-rbt-tune.conf > /dev/null <<EOF
# بهینه‌سازی سیستم RBT
fs.file-max = 1048576
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_forward = 1
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
EOF
    
    # اعمال تنظیمات sysctl
    $SUDO sysctl --system
    
    # افزایش محدودیت‌های فایل
    $SUDO tee /etc/security/limits.d/99-rbt.conf > /dev/null <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
EOF
    
    print_success_fa "بهینه‌سازی سیستم کامل شد."
}

# نمایش منوی فارسی
display_menu_fa() {
    clear
    print_header_fa
    echo -e "${CYAN}لطفاً یک گزینه انتخاب کنید:${NC}"
    echo
    echo -e "${WHITE}1)${NC} نصب سریع (تنظیمات پیش‌فرض)"
    echo -e "${WHITE}2)${NC} نصب سفارشی (پیکربندی تعاملی)"
    echo -e "${WHITE}3)${NC} فقط نصب منوی سیستم"
    echo -e "${WHITE}4)${NC} فقط نصب باینری RBT"
    echo -e "${WHITE}5)${NC} فقط بهینه‌سازی سیستم"
    echo -e "${WHITE}6)${NC} حذف RBT"
    echo -e "${WHITE}7)${NC} به‌روزرسانی RBT"
    echo -e "${WHITE}8)${NC} اجرای منوی تعاملی"
    echo -e "${WHITE}9)${NC} گزینه‌های پیشرفته"
    echo -e "${WHITE}0)${NC} خروج"
    echo
    read -p "انتخاب خود را وارد کنید [0-9]: " choice
    echo
}

# نصب RBT
install_rbt_fa() {
    check_root_fa
    detect_pkg_manager_fa
    install_dependencies_fa
    
    if [[ "$MENU_ONLY" == "true" ]]; then
        install_menu_only_fa
        return
    fi
    
    optimize_system_fa
    
    print_status_fa "در حال نصب باینری RBT..."
    
    # تلاش برای دانلود باینری از پیش‌ساخته شده
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r ".assets[] | select(.name | contains(\"linux-amd64\")) | .browser_download_url" 2>/dev/null || echo "")
    
    if [[ -n "$DOWNLOAD_URL" ]] && [[ "$DOWNLOAD_URL" != "null" ]]; then
        print_status_fa "در حال دانلود باینری از پیش‌ساخته شده..."
        curl -L "$DOWNLOAD_URL" -o rbt
        chmod +x rbt
        $SUDO mv rbt "$INSTALL_PATH"
        print_success_fa "باینری RBT با موفقیت نصب شد."
    else
        print_status_fa "در حال ساخت از منبع..."
        
        # نصب وابستگی‌های ساخت
        $PKG_INSTALL git openssl pkg-config libssl-dev build-essential
        
        # نصب Rust در صورت عدم وجود
        if ! command -v cargo &> /dev/null; then
            print_status_fa "در حال نصب Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source ~/.cargo/env
        fi
        
        # کلون و ساخت
        REPO_DIR="/opt/RBT"
        if [[ -d "$REPO_DIR" ]]; then
            cd "$REPO_DIR"
            git pull
        else
            git clone "https://github.com/$REPO.git" "$REPO_DIR"
            cd "$REPO_DIR"
        fi
        
        cargo build --release --bin rbt-cli
        $SUDO cp target/release/rbt-cli "$INSTALL_PATH"
        print_success_fa "باینری RBT ساخته و نصب شد."
    fi
    
    # نصب منوی سیستم
    install_menu_only_fa
    
    # اضافه کردن به PATH در صورت نیاز
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
        print_warning_fa "/usr/local/bin به PATH اضافه شد. لطفاً شل خود را مجدداً راه‌اندازی کنید یا اجرا کنید: source ~/.bashrc"
    fi
    
    print_success_fa "نصب با موفقیت کامل شد!"
    print_status_fa "اکنون می‌توانید 'rbt' را اجرا کنید یا 'rbt-menu' را برای منوی تعاملی اجرا کنید."
}

# نصب فقط منوی سیستم
install_menu_only_fa() {
    print_status_fa "در حال نصب منوی سیستم..."
    
    $SUDO mkdir -p /opt/rbt-menu
    
    # دانلود فایل‌های منو
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/rbt-menu.ts" | $SUDO tee /opt/rbt-menu/rbt-menu.ts > /dev/null
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/interactive-installer.ts" | $SUDO tee /opt/rbt-menu/installer.ts > /dev/null
    
    # ایجاد اسکریپت wrapper
    $SUDO tee /usr/local/bin/rbt-menu > /dev/null <<'EOF'
#!/bin/bash
cd /opt/rbt-menu
npx tsx rbt-menu.ts "$@"
EOF
    
    $SUDO chmod +x /usr/local/bin/rbt-menu
    
    print_success_fa "منوی سیستم نصب شد. برای استفاده 'rbt-menu' را اجرا کنید."
}

# حذف RBT
uninstall_rbt_fa() {
    print_warning_fa "این RBT را به طور کامل از سیستم شما حذف می‌کند."
    read -p "آیا مطمئن هستید؟ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    print_status_fa "در حال حذف RBT..."
    
    $SUDO rm -f "$INSTALL_PATH"
    $SUDO rm -rf /etc/rbt
    $SUDO rm -f /etc/sysctl.d/99-rbt-tune.conf
    $SUDO rm -f /etc/security/limits.d/99-rbt.conf
    $SUDO rm -f /usr/local/bin/rbt-menu
    $SUDO rm -rf /opt/rbt-menu
    
    print_success_fa "RBT حذف شده است."
}

# اجرای نصب کننده تعاملی
run_interactive_installer_fa() {
    print_status_fa "در حال اجرای نصب کننده تعاملی..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/interactive-installer.ts" -o interactive-installer.ts
    
    if command -v npx &> /dev/null; then
        npx tsx interactive-installer.ts
    else
        print_error_fa "npx پیدا نشد. لطفاً ابتدا Node.js را نصب کنید."
        exit 1
    fi
    
    cd /
    rm -rf "$TEMP_DIR"
}

# اجرای منوی تعاملی
run_interactive_menu_fa() {
    print_status_fa "در حال راه‌اندازی منوی تعاملی..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/rbt-menu.ts" -o rbt-menu.ts
    
    if command -v npx &> /dev/null; then
        npx tsx rbt-menu.ts
    else
        print_error_fa "npx پیدا نشد. لطفاً ابتدا Node.js را نصب کنید."
        exit 1
    fi
    
    cd /
    rm -rf "$TEMP_DIR"
}

# تجزیه تحلیل آرگومان‌های خط فرمان
while [[ $# -gt 0 ]]; do
    case $1 in
        --menu-only)
            MENU_ONLY=true
            INTERACTIVE_MODE=false
            shift
            ;;
        --skip-system-config)
            SKIP_SYSTEM_CONFIG=true
            shift
            ;;
        --non-interactive)
            INTERACTIVE_MODE=false
            shift
            ;;
        --help|-h)
            echo "استفاده: $0 [گزینه‌ها]"
            echo
            echo "گزینه‌ها:"
            echo "  --menu-only          فقط نصب منوی سیستم"
            echo "  --skip-system-config از پیکربندی سیستم صرف‌نظر کنید"
            echo "  --non-interactive    در حالت غیرتعاملی اجرا شود"
            echo "  --help, -h           نمایش این پیام کمک"
            echo
            echo "نصب یک‌خطی:"
            echo "  bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-persian.sh)"
            exit 0
            ;;
        *)
            print_error_fa "گزینه ناشناخته: $1"
            echo "برای اطلاعات استفاده از --help استفاده کنید."
            exit 1
            ;;
    esac
done

# برنامه اصلی
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    while true; do
        display_menu_fa
        
        case $choice in
            1)
                install_rbt_fa
                break
                ;;
            2)
                run_interactive_installer_fa
                break
                ;;
            3)
                MENU_ONLY=true
                install_rbt_fa
                break
                ;;
            4)
                # نصب فقط باینری
                check_root_fa
                detect_pkg_manager_fa
                install_dependencies_fa
                install_rbt_binary
                break
                ;;
            5)
                check_root_fa
                optimize_system_fa
                break
                ;;
            6)
                uninstall_rbt_fa
                break
                ;;
            7)
                # به‌روزرسانی RBT
                check_root_fa
                detect_pkg_manager_fa
                install_dependencies_fa
                optimize_system_fa
                install_rbt_binary
                install_menu_only_fa
                break
                ;;
            8)
                run_interactive_menu_fa
                break
                ;;
            0)
                print_status_fa "نصب لغو شد."
                exit 0
                ;;
            *)
                print_error_fa "انتخاب نامعتبر. لطفاً دوباره تلاش کنید."
                sleep 2
                ;;
        esac
    done
else
    install_rbt_fa
fi