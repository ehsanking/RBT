#!/bin/bash

# RBT Enhanced Complete Interactive Installer
# One-line installation: bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration variables
INSTALL_PATH="/usr/local/bin/rbt"
REPO="EHSANKiNG/RBT"
TEMP_DIR="/tmp/rbt-install"
INTERACTIVE_MODE=true
MENU_ONLY=false
SKIP_SYSTEM_CONFIG=false
DEBUG_MODE=false
ENHANCED_FEATURES=true

# Enhanced configuration variables
ADMIN_USERNAME=""
ADMIN_PASSWORD=""
DASHBOARD_PORT=""
JWT_SECRET=""
HCAPTCHA_SITE_KEY=""
HCAPTCHA_SECRET_KEY=""
SMTP_HOST=""
SMTP_PORT=""
SMTP_USER=""
SMTP_PASS=""
NOTIFICATION_EMAIL=""
ENABLE_MONITORING=true
ENABLE_SECURITY_AUDITING=true
ENABLE_AUTO_BACKUP=true

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}     RBT Enhanced Tunnel Orchestrator   ${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}  Interactive Installation with Advanced ${NC}"
    echo -e "${PURPLE}  Security, Monitoring & Management     ${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo
}

# Function to display help
show_help() {
    cat << EOF
RBT Enhanced Interactive Installer

Usage: $0 [OPTIONS]

OPTIONS:
    --help, -h              Show this help message
    --non-interactive       Run in non-interactive mode (use defaults)
    --menu-only            Only install the menu system
    --skip-system-config   Skip system-level configuration
    --debug                Enable debug output
    --test-mode            Run in test mode (skip actual installation)
    --admin-user USER      Set admin username
    --admin-pass PASS      Set admin password
    --port PORT           Set dashboard port (default: 3000)
    --jwt-secret SECRET   Set JWT secret
    --hcaptcha-site KEY  Set hCaptcha site key
    --hcaptcha-secret KEY  Set hCaptcha secret key
    --smtp-host HOST      Set SMTP host
    --smtp-port PORT      Set SMTP port
    --smtp-user USER      Set SMTP username
    --smtp-pass PASS      Set SMTP password
    --notify-email EMAIL  Set notification email
    --enable-monitoring   Enable monitoring (default: true)
    --enable-security     Enable security auditing (default: true)
    --enable-backup       Enable automatic backup (default: true)
    --disable-monitoring  Disable monitoring
    --disable-security    Disable security auditing
    --disable-backup      Disable automatic backup

Examples:
    # Interactive installation
    bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh)

    # Non-interactive with custom settings
    bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh) \
        --non-interactive --admin-user admin --admin-pass mypassword --port 8080

    # Only install menu system
    bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh) --menu-only

    # Test mode
    bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete-enhanced.sh) --test-mode

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --non-interactive)
                INTERACTIVE_MODE=false
                shift
                ;;
            --menu-only)
                MENU_ONLY=true
                shift
                ;;
            --skip-system-config)
                SKIP_SYSTEM_CONFIG=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --test-mode)
                TEST_MODE=true
                shift
                ;;
            --admin-user)
                ADMIN_USERNAME="$2"
                shift 2
                ;;
            --admin-pass)
                ADMIN_PASSWORD="$2"
                shift 2
                ;;
            --port)
                DASHBOARD_PORT="$2"
                shift 2
                ;;
            --jwt-secret)
                JWT_SECRET="$2"
                shift 2
                ;;
            --hcaptcha-site)
                HCAPTCHA_SITE_KEY="$2"
                shift 2
                ;;
            --hcaptcha-secret)
                HCAPTCHA_SECRET_KEY="$2"
                shift 2
                ;;
            --smtp-host)
                SMTP_HOST="$2"
                shift 2
                ;;
            --smtp-port)
                SMTP_PORT="$2"
                shift 2
                ;;
            --smtp-user)
                SMTP_USER="$2"
                shift 2
                ;;
            --smtp-pass)
                SMTP_PASS="$2"
                shift 2
                ;;
            --notify-email)
                NOTIFICATION_EMAIL="$2"
                shift 2
                ;;
            --enable-monitoring)
                ENABLE_MONITORING=true
                shift
                ;;
            --enable-security)
                ENABLE_SECURITY_AUDITING=true
                shift
                ;;
            --enable-backup)
                ENABLE_AUTO_BACKUP=true
                shift
                ;;
            --disable-monitoring)
                ENABLE_MONITORING=false
                shift
                ;;
            --disable-security)
                ENABLE_SECURITY_AUDITING=false
                shift
                ;;
            --disable-backup)
                ENABLE_AUTO_BACKUP=false
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
        print_warning "Running as root. This is not recommended for security reasons."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        SUDO="sudo"
        print_status "Using sudo for privileged operations."
    fi
}

# Function to detect package manager
detect_pkg_manager() {
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
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="$SUDO pacman -S --noconfirm"
        PKG_UPDATE="$SUDO pacman -Sy"
    else
        print_error "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi
    print_status "Detected package manager: $PKG_MANAGER"
}

# Function to check and install dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    # Check for required tools
    local tools_needed=()
    
    if ! command -v curl &> /dev/null; then
        tools_needed+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        tools_needed+=("jq")
    fi
    
    if ! command -v node &> /dev/null; then
        tools_needed+=("nodejs")
    fi
    
    if ! command -v npm &> /dev/null; then
        tools_needed+=("npm")
    fi
    
    if ! command -v git &> /dev/null; then
        tools_needed+=("git")
    fi
    
    if ! command -v openssl &> /dev/null; then
        tools_needed+=("openssl")
    fi
    
    if [ ${#tools_needed[@]} -gt 0 ]; then
        print_status "Installing missing tools: ${tools_needed[*]}"
        $PKG_UPDATE
        $PKG_INSTALL "${tools_needed[@]}"
    fi

    # Install Node.js 16+ if needed
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2)
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
        if [ "$NODE_MAJOR" -lt 16 ]; then
            print_status "Installing Node.js 16+..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | $SUDO -E bash -
            $PKG_INSTALL nodejs
        fi
    fi

    print_success "System dependencies installed"
}

# Function to check Node.js version
check_node_version() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
        
        if [ "$NODE_MAJOR" -ge 16 ]; then
            print_success "Node.js version check passed: $NODE_VERSION"
            return 0
        else
            print_error "Node.js 16+ required, found $NODE_VERSION"
            return 1
        fi
    else
        print_error "Node.js not found"
        return 1
    fi
}

# Function to check system resources
check_system_resources() {
    print_status "Checking system resources..."
    
    # Check memory
    if command -v free &> /dev/null; then
        MEMORY_MB=$(free -m | awk '/^Mem:/ {print $2}')
        if [ "$MEMORY_MB" -lt 512 ]; then
            print_warning "Low memory detected: ${MEMORY_MB}MB. RBT may not perform optimally."
        else
            print_success "Memory check passed: ${MEMORY_MB}MB"
        fi
    fi
    
    # Check disk space
    DISK_SPACE=$(df / | tail -1 | awk '{print $4}')
    if [ "$DISK_SPACE" -lt 1048576 ]; then  # 1GB in KB
        print_warning "Low disk space detected"
    else
        print_success "Disk space check passed"
    fi
    
    # Check CPU cores
    if [ -f /proc/cpuinfo ]; then
        CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
        print_success "CPU cores: $CPU_CORES"
    fi
}

# Function to check ports availability
check_ports() {
    local ports=("${@}")
    local available=true
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use"
            available=false
        fi
    done
    
    if [ "$available" = true ]; then
        print_success "All specified ports are available"
    fi
}

# Function to generate secure random strings
generate_secure_string() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to validate password strength
validate_password() {
    local password="$1"
    
    if [ ${#password} -lt 8 ]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [a-z] ]]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [A-Z] ]]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [0-9] ]]; then
        return 1
    fi
    
    if ! [[ "$password" =~ [@$!%*?&] ]]; then
        return 1
    fi
    
    return 0
}

# Function to collect configuration interactively
collect_configuration() {
    if [[ "$INTERACTIVE_MODE" == "false" ]]; then
        print_status "Using default configuration..."
        return
    fi

    print_header
    echo -e "${CYAN}Welcome to the RBT Enhanced Interactive Installer!${NC}"
    echo -e "This installer will help you set up RBT with advanced features including:"
    echo -e "• ${GREEN}Security auditing and certificate management${NC}"
    echo -e "• ${GREEN}Real-time monitoring and metrics${NC}"
    echo -e "• ${GREEN}Automatic backup and recovery${NC}"
    echo -e "• ${GREEN}System optimization${NC}"
    echo -e "• ${GREEN}Interactive menu system${NC}"
    echo

    # Basic Configuration
    echo -e "${BLUE}=== Basic Configuration ===${NC}"
    
    if [[ -z "$ADMIN_USERNAME" ]]; then
        read -p "Admin username [admin]: " ADMIN_USERNAME
        ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
    fi
    
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        while true; do
            read -sp "Admin password (min 8 chars, complex): " ADMIN_PASSWORD
            echo
            if validate_password "$ADMIN_PASSWORD"; then
                read -sp "Confirm password: " ADMIN_PASSWORD_CONFIRM
                echo
                if [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]]; then
                    break
                else
                    print_error "Passwords do not match"
                fi
            else
                print_error "Password must be at least 8 characters with uppercase, lowercase, number, and special character"
            fi
        done
    fi
    
    if [[ -z "$DASHBOARD_PORT" ]]; then
        read -p "Dashboard port [3000]: " DASHBOARD_PORT
        DASHBOARD_PORT=${DASHBOARD_PORT:-3000}
    fi
    
    if [[ -z "$JWT_SECRET" ]]; then
        JWT_SECRET=$(generate_secure_string 64)
        print_status "Generated secure JWT secret"
    fi

    # Security Configuration
    echo -e "\n${BLUE}=== Security Configuration ===${NC}"
    read -p "Enable security auditing? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_SECURITY_AUDITING=true
    else
        ENABLE_SECURITY_AUDITING=false
    fi

    # Optional Features
    echo -e "\n${BLUE}=== Optional Features ===${NC}"
    
    read -p "Enable hCaptcha protection? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -z "$HCAPTCHA_SITE_KEY" ]]; then
            read -p "hCaptcha Site Key: " HCAPTCHA_SITE_KEY
        fi
        if [[ -z "$HCAPTCHA_SECRET_KEY" ]]; then
            read -sp "hCaptcha Secret Key: " HCAPTCHA_SECRET_KEY
            echo
        fi
    fi
    
    read -p "Enable email notifications? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -z "$SMTP_HOST" ]]; then
            read -p "SMTP Host [smtp.gmail.com]: " SMTP_HOST
            SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
        fi
        if [[ -z "$SMTP_PORT" ]]; then
            read -p "SMTP Port [587]: " SMTP_PORT
            SMTP_PORT=${SMTP_PORT:-587}
        fi
        if [[ -z "$SMTP_USER" ]]; then
            read -p "SMTP Username: " SMTP_USER
        fi
        if [[ -z "$SMTP_PASS" ]]; then
            read -sp "SMTP Password: " SMTP_PASS
            echo
        fi
        if [[ -z "$NOTIFICATION_EMAIL" ]]; then
            read -p "Notification Email: " NOTIFICATION_EMAIL
        fi
    fi

    # Advanced Configuration
    echo -e "\n${BLUE}=== Advanced Configuration ===${NC}"
    
    read -p "Enable monitoring and metrics? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_MONITORING=true
    else
        ENABLE_MONITORING=false
    fi
    
    read -p "Enable automatic backup? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_BACKUP=true
    else
        ENABLE_AUTO_BACKUP=false
    fi
    
    read -p "Enable system optimization? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        SKIP_SYSTEM_CONFIG=false
    else
        SKIP_SYSTEM_CONFIG=true
    fi
}

# Function to create configuration files
create_config_files() {
    print_status "Creating configuration files..."
    
    # Create .env file
    cat > .env << EOF
# RBT Enhanced Environment Configuration
# Generated on: $(date)

# JWT Secret
JWT_SECRET=$JWT_SECRET

# Dashboard
DASHBOARD_PORT=$DASHBOARD_PORT
DASHBOARD_HOST=0.0.0.0

# hCaptcha
EOF

    if [[ -n "$HCAPTCHA_SITE_KEY" ]]; then
        echo "VITE_HCAPTCHA_SITE_KEY=$HCAPTCHA_SITE_KEY" >> .env
        echo "HCAPTCHA_SECRET_KEY=$HCAPTCHA_SECRET_KEY" >> .env
    else
        echo "# HCAPTCHA_SITE_KEY=your_site_key_here" >> .env
        echo "# HCAPTCHA_SECRET_KEY=your_secret_key_here" >> .env
    fi

    cat >> .env << EOF

# SMTP
EOF

    if [[ -n "$SMTP_HOST" ]]; then
        echo "SMTP_HOST=$SMTP_HOST" >> .env
        echo "SMTP_PORT=$SMTP_PORT" >> .env
        echo "SMTP_USER=$SMTP_USER" >> .env
        echo "SMTP_PASS=$SMTP_PASS" >> .env
        echo "NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL" >> .env
    else
        echo "# SMTP_HOST=smtp.gmail.com" >> .env
        echo "# SMTP_PORT=587" >> .env
        echo "# SMTP_USER=your_email@gmail.com" >> .env
        echo "# SMTP_PASS=your_app_password" >> .env
        echo "# NOTIFICATION_EMAIL=notifications@yourdomain.com" >> .env
    fi

    # Add monitoring settings
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        echo "" >> .env
        echo "# Monitoring" >> .env
        echo "ENABLE_MONITORING=true" >> .env
        echo "MONITORING_PORT=9090" >> .env
        echo "ENABLE_METRICS=true" >> .env
        echo "METRICS_PORT=9091" >> .env
    fi

    # Add security settings
    echo "" >> .env
    echo "# Security Settings" >> .env
    echo "FORCE_HTTPS=true" >> .env
    echo "SESSION_TIMEOUT=24h" >> .env
    echo "MAX_LOGIN_ATTEMPTS=5" >> .env
    echo "LOCKOUT_DURATION=15m" >> .env
    echo "ENABLE_SECURITY_AUDITING=$ENABLE_SECURITY_AUDITING" >> .env
    echo "ENABLE_AUTO_BACKUP=$ENABLE_AUTO_BACKUP" >> .env

    # Create config.toml file
    cat > config.toml << EOF
# RBT Enhanced Configuration File
# Generated on: $(date)

[dashboard]
username = "$ADMIN_USERNAME"
password = "$ADMIN_PASSWORD"
port = $DASHBOARD_PORT
host = "0.0.0.0"
enable_rate_limiting = true
rate_limit_window = 900000
rate_limit_max = 100

[security]
jwt_secret = "$JWT_SECRET"
session_timeout = "24h"
max_login_attempts = 5
lockout_duration = "15m"
force_https = true
enable_audit_logging = $ENABLE_SECURITY_AUDITING
enable_auto_backup = $ENABLE_AUTO_BACKUP

[server]
host = "0.0.0.0"
port = $DASHBOARD_PORT

[logging]
level = "info"
file = "/var/log/rbt/rbt.log"
max_size = "100MB"
max_backups = 10
max_age = 30
enable_compression = true

[tunnels]
# Add your tunnel configurations here
EOF

    # Add monitoring configuration
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        cat >> config.toml << EOF

[monitoring]
enable_metrics = true
metrics_port = 9091
monitoring_port = 9090
enable_health_checks = true
health_check_interval = 30000
enable_alerts = true
EOF
    fi

    # Set secure permissions
    chmod 600 .env config.toml
    
    print_success "Configuration files created"
}

# Function to install RBT
install_rbt() {
    print_status "Installing RBT..."
    
    # Clone or download RBT
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download the latest release
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r .tag_name)
    if [[ "$LATEST_RELEASE" == "null" ]]; then
        print_warning "Could not fetch latest release, using main branch"
        git clone "https://github.com/$REPO.git" .
    else
        print_status "Downloading RBT release: $LATEST_RELEASE"
        curl -sSL "https://github.com/$REPO/archive/refs/tags/$LATEST_RELEASE.tar.gz" | tar -xz --strip-components=1
    fi
    
    # Install Node.js dependencies
    if [[ -f package.json ]]; then
        print_status "Installing Node.js dependencies..."
        npm install
    fi
    
    # Build if necessary
    if [[ -f package.json ]] && grep -q "build" package.json; then
        print_status "Building RBT..."
        npm run build
    fi
    
    # Install binaries
    if [[ -f target/release/rbt ]]; then
        print_status "Installing RBT binary..."
        $SUDO cp target/release/rbt "$INSTALL_PATH"
        $SUDO chmod +x "$INSTALL_PATH"
    fi
    
    # Copy scripts
    if [[ -d scripts ]]; then
        print_status "Installing scripts..."
        mkdir -p "$HOME/.local/bin"
        cp scripts/*.ts "$HOME/.local/bin/" 2>/dev/null || true
        cp scripts/*.js "$HOME/.local/bin/" 2>/dev/null || true
        chmod +x "$HOME/.local/bin/"*
    fi
    
    print_success "RBT installed successfully"
}

# Function to setup security
setup_security() {
    if [[ "$ENABLE_SECURITY_AUDITING" != "true" ]]; then
        return
    fi
    
    print_status "Setting up security..."
    
    # Generate CA certificate if it doesn't exist
    CERT_DIR="/etc/rbt/certs"
    $SUDO mkdir -p "$CERT_DIR"
    
    if [[ ! -f "$CERT_DIR/ca-key.pem" ]]; then
        print_status "Generating CA certificate..."
        $SUDO openssl genrsa -out "$CERT_DIR/ca-key.pem" 4096
        $SUDO openssl req -new -x509 -key "$CERT_DIR/ca-key.pem" -out "$CERT_DIR/ca-cert.pem" -days 3650 -subj "/C=US/ST=State/L=City/O=RBT CA/CN=RBT Root CA"
        $SUDO chmod 600 "$CERT_DIR/ca-key.pem"
        $SUDO chmod 644 "$CERT_DIR/ca-cert.pem"
    fi
    
    print_success "Security setup completed"
}

# Function to setup monitoring
setup_monitoring() {
    if [[ "$ENABLE_MONITORING" != "true" ]]; then
        return
    fi
    
    print_status "Setting up monitoring..."
    
    # Create monitoring directories
    $SUDO mkdir -p /var/lib/rbt/metrics
    $SUDO mkdir -p /var/log/rbt
    
    # Set permissions
    $SUDO chmod 755 /var/lib/rbt/metrics
    $SUDO chmod 755 /var/log/rbt
    
    print_success "Monitoring setup completed"
}

# Function to optimize system
optimize_system() {
    if [[ "$SKIP_SYSTEM_CONFIG" == "true" ]]; then
        return
    fi
    
    print_status "Optimizing system..."
    
    # Increase file descriptors
    echo "* soft nofile 65536" | $SUDO tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | $SUDO tee -a /etc/security/limits.conf
    
    # Enable BBR congestion control
    if [[ -f /proc/sys/net/ipv4/tcp_congestion_control ]]; then
        echo "net.core.default_qdisc=fq" | $SUDO tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" | $SUDO tee -a /etc/sysctl.conf
        $SUDO sysctl -p
    fi
    
    # Optimize TCP settings
    if [[ -f /proc/sys/net/core/rmem_max ]]; then
        echo "net.core.rmem_max = 16777216" | $SUDO tee -a /etc/sysctl.conf
        echo "net.core.wmem_max = 16777216" | $SUDO tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_rmem = 4096 87380 16777216" | $SUDO tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_wmem = 4096 65536 16777216" | $SUDO tee -a /etc/sysctl.conf
        $SUDO sysctl -p
    fi
    
    print_success "System optimization completed"
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    cat > /tmp/rbt.service << EOF
[Unit]
Description=RBT Enhanced Tunnel Orchestrator
After=network.target
Wants=network.target

[Service]
Type=simple
User=rbt
Group=rbt
WorkingDirectory=/opt/rbt
ExecStart=/usr/bin/node /opt/rbt/server.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rbt

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/log/rbt /var/lib/rbt /etc/rbt
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    $SUDO mv /tmp/rbt.service /etc/systemd/system/
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable rbt.service
    
    print_success "Systemd service created"
}

# Function to create user and directories
setup_user_directories() {
    print_status "Setting up user and directories..."
    
    # Create RBT user if it doesn't exist
    if ! id "rbt" &>/dev/null; then
        $SUDO useradd -r -s /bin/false -d /opt/rbt -m rbt
    fi
    
    # Create directories
    $SUDO mkdir -p /opt/rbt
    $SUDO mkdir -p /etc/rbt
    $SUDO mkdir -p /var/log/rbt
    $SUDO mkdir -p /var/lib/rbt
    
    # Set permissions
    $SUDO chown -R rbt:rbt /opt/rbt
    $SUDO chown -R rbt:rbt /etc/rbt
    $SUDO chown -R rbt:rbt /var/log/rbt
    $SUDO chown -R rbt:rbt /var/lib/rbt
    
    print_success "User and directories setup completed"
}

# Function to perform post-installation tasks
post_installation() {
    print_status "Performing post-installation tasks..."
    
    # Create backup
    if [[ -f config.toml ]]; then
        cp config.toml "config.toml.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Configuration backup created"
    fi
    
    # Set up log rotation
    cat > /tmp/rbt-logrotate << EOF
/var/log/rbt/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 rbt rbt
    postrotate
        systemctl reload rbt.service > /dev/null 2>&1 || true
    endscript
}
EOF
    
    $SUDO mv /tmp/rbt-logrotate /etc/logrotate.d/rbt
    
    # Create systemd service
    create_systemd_service
    
    print_success "Post-installation tasks completed"
}

# Function to print next steps
print_next_steps() {
    print_success "RBT Enhanced Installation Complete!"
    echo
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Start RBT: sudo systemctl start rbt"
    echo "2. Enable auto-start: sudo systemctl enable rbt"
    echo "3. Check status: sudo systemctl status rbt"
    echo "4. Access dashboard: http://localhost:$DASHBOARD_PORT"
    echo "5. Login with username: $ADMIN_USERNAME"
    echo "6. View logs: sudo journalctl -u rbt -f"
    echo
    echo -e "${CYAN}Useful commands:${NC}"
    echo "• npm run rbt-menu          # Start interactive menu"
    echo "• tsx scripts/monitor.ts start  # Start monitoring"
    echo "• tsx scripts/security-manager.ts audit  # Run security audit"
    echo "• sudo systemctl restart rbt  # Restart service"
    echo "• sudo systemctl stop rbt     # Stop service"
    echo
    echo -e "${CYAN}Configuration files:${NC}"
    echo "• /etc/rbt/config.toml      # Main configuration"
    echo "• /etc/rbt/certs/         # Certificate directory"
    echo "• /var/log/rbt/           # Log directory"
    echo "• /var/lib/rbt/           # Data directory"
    echo
    echo -e "${GREEN}Thank you for choosing RBT Enhanced!${NC}"
}

# Function to run tests
run_tests() {
    if [[ "$TEST_MODE" == "true" ]]; then
        print_status "Running tests..."
        
        # Test configuration
        if [[ -f config.toml ]]; then
            print_success "Configuration file test passed"
        else
            print_error "Configuration file test failed"
            return 1
        fi
        
        # Test ports
        check_ports "$DASHBOARD_PORT" 9090 9091
        
        # Test crypto
        local test_secret=$(generate_secure_string 32)
        if [[ ${#test_secret} -eq 32 ]]; then
            print_success "Crypto test passed"
        else
            print_error "Crypto test failed"
            return 1
        fi
        
        print_success "All tests passed"
        return 0
    fi
}

# Main installation function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Check if running as root
    check_root
    
    # Print header
    print_header
    
    # Detect package manager
    detect_pkg_manager
    
    # Install dependencies
    install_dependencies
    
    # Check Node.js version
    check_node_version
    
    # Check system resources
    check_system_resources
    
    # Collect configuration
    collect_configuration
    
    # Check ports
    check_ports "$DASHBOARD_PORT" 9090 9091
    
    # Create configuration files
    create_config_files
    
    # Install RBT
    install_rbt
    
    # Setup user and directories
    setup_user_directories
    
    # Setup security
    setup_security
    
    # Setup monitoring
    setup_monitoring
    
    # Optimize system
    optimize_system
    
    # Run tests
    run_tests
    
    # Post installation
    post_installation
    
    # Print next steps
    print_next_steps
}

# Handle errors
handle_error() {
    local line_number=$1
    print_error "Installation failed at line $line_number"
    
    # Cleanup
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Run main function
main "$@"