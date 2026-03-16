#!/bin/bash

# RBT DNS Manager Installation Script
# Installs all dependencies and sets up the DNS management system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This is not recommended for security reasons."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is designed for Linux systems only"
        exit 1
    fi
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
    
    if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 8 ]]; then
        log_error "Python 3.8 or higher is required. Found: $PYTHON_VERSION"
        exit 1
    fi
    
    # Check for required tools
    local tools=("curl" "git" "gcc" "make")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool is not installed"
            exit 1
        fi
    done
    
    log_success "System requirements check passed"
}

# Install system dependencies
install_system_deps() {
    log_info "Installing system dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y python3-pip python3-dev build-essential \
            libssl-dev libffi-dev python3-setuptools curl git
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        sudo yum install -y python3-pip python3-devel gcc openssl-devel \
            libffi-devel curl git
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S --noconfirm python-pip base-devel openssl libffi curl git
    else
        log_error "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi
    
    log_success "System dependencies installed"
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies..."
    
    # Upgrade pip
    python3 -m pip install --upgrade pip
    
    # Install required packages
    python3 -m pip install --user --upgrade \
        dnspython \
        asyncio \
        aiohttp \
        requests \
        pysocks \
        urllib3 \
        cryptography \
        pyopenssl \
        certifi
    
    log_success "Python dependencies installed"
}

# Install Go (for dnstt)
install_go() {
    log_info "Installing Go..."
    
    # Check if Go is already installed
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        log_info "Go is already installed: $GO_VERSION"
        return 0
    fi
    
    # Download and install Go
    GO_VERSION="1.21.5"
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64)
            GO_ARCH="amd64"
            ;;
        aarch64)
            GO_ARCH="arm64"
            ;;
        armv7l)
            GO_ARCH="armv6l"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    GO_URL="https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    GO_INSTALL_DIR="$HOME/go"
    
    log_info "Downloading Go ${GO_VERSION} for ${ARCH}..."
    curl -L "$GO_URL" -o /tmp/go.tar.gz
    
    log_info "Installing Go to $GO_INSTALL_DIR..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    export PATH=$PATH:/usr/local/go/bin
    
    log_success "Go installed successfully"
}

# Setup RBT DNS Manager
setup_dns_manager() {
    log_info "Setting up RBT DNS Manager..."
    
    # Create directories
    mkdir -p ~/rbt-dns/{logs,config,data}
    
    # Copy DNS data files if they exist
    if [[ -f "high_reliability_dns.json" ]]; then
        cp high_reliability_dns.json ~/rbt-dns/data/
        log_info "Copied high-reliability DNS servers data"
    fi
    
    if [[ -f "dns_by_country.json" ]]; then
        cp dns_by_country.json ~/rbt-dns/data/
        log_info "Copied DNS servers by country data"
    fi
    
    # Create systemd service for DNS management
    cat > /tmp/rbt-dns-manager.service << EOF
[Unit]
Description=RBT DNS Manager
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/rbt-dns
ExecStart=/usr/bin/python3 dns_automation.py --init
Restart=always
RestartSec=30
Environment=PYTHONPATH=$HOME/rbt-dns

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp /tmp/rbt-dns-manager.service /etc/systemd/system/
    sudo systemctl daemon-reload
    
    log_success "RBT DNS Manager setup completed"
}

# Install dnstt
install_dnstt() {
    log_info "Installing dnstt (DNS tunneling)..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd $TEMP_DIR
    
    # Clone dnstt repository
    log_info "Cloning dnstt repository..."
    git clone --depth 1 https://github.com/getlantern/dnstt.git
    cd dnstt
    
    # Build server
    log_info "Building dnstt server..."
    cd server
    go build -o dnstt-server
    sudo cp dnstt-server /usr/local/bin/
    cd ..
    
    # Build client
    log_info "Building dnstt client..."
    cd client
    go build -o dnstt-client
    sudo cp dnstt-client /usr/local/bin/
    cd ..
    
    # Cleanup
    cd ~
    rm -rf $TEMP_DIR
    
    log_success "dnstt installed successfully"
}

# Create configuration
create_config() {
    log_info "Creating configuration files..."
    
    # Create main configuration
    cat > ~/rbt-dns/config/dns_config.json << 'EOF'
{
  "dns_manager": {
    "test_domains": [
      "google.com",
      "cloudflare.com", 
      "microsoft.com",
      "amazon.com",
      "github.com",
      "stackoverflow.com",
      "wikipedia.org",
      "reddit.com"
    ],
    "timeout": 5.0,
    "max_concurrent": 50,
    "reliability_threshold": 0.95,
    "preferred_countries": ["US", "CA", "GB", "DE", "NL", "FR", "CH"],
    "monitoring_interval": 300,
    "emergency_countries": ["RU", "CN", "IR", "IN", "BR", "JP", "KR"]
  },
  
  "dns_tunnel": {
    "default_socks_port": 9050,
    "server_port": 53,
    "timeout": 30,
    "mtu": 1500,
    "dns_server": "1.1.1.1"
  },
  
  "iran_testing": {
    "blocked_domains": [
      "youtube.com",
      "facebook.com", 
      "twitter.com",
      "telegram.org",
      "instagram.com"
    ],
    "dns_poisoning_ips": [
      "10.10.34.34",
      "10.10.34.35", 
      "127.0.0.1"
    ]
  },
  
  "performance_metrics": {
    "latency_thresholds": {
      "excellent": 20,
      "good": 50,
      "acceptable": 100,
      "degraded": 200,
      "critical": 500
    },
    "success_rate_thresholds": {
      "excellent": 0.95,
      "good": 0.80,
      "acceptable": 0.60,
      "poor": 0.40
    }
  }
}
EOF

    log_success "Configuration files created"
}

# Create scripts
create_scripts() {
    log_info "Creating management scripts..."
    
    # DNS test script
    cat > ~/rbt-dns/test-dns.sh << 'EOF'
#!/bin/bash
cd ~/rbt-dns
python3 dns_automation.py --test-dns
EOF
    chmod +x ~/rbt-dns/test-dns.sh
    
    # Status script
    cat > ~/rbt-dns/status.sh << 'EOF'
#!/bin/bash
cd ~/rbt-dns
python3 dns_automation.py --status
EOF
    chmod +x ~/rbt-dns/status.sh
    
    # Start tunnel script
    cat > ~/rbt-dns/start-tunnel.sh << 'EOF'
#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <server-ip>"
    exit 1
fi
cd ~/rbt-dns
python3 dns_automation.py --setup-tunnel --domain "$1" --server-ip "$2"
EOF
    chmod +x ~/rbt-dns/start-tunnel.sh
    
    # Test Iran connectivity
    cat > ~/rbt-dns/test-iran.sh << 'EOF'
#!/bin/bash
cd ~/rbt-dns
echo "Testing DNS tunnel for Iranian network conditions..."
python3 dns_automation.py --setup-tunnel --domain test.example.com --server-ip 1.2.3.4
python3 dns_automation.py --start-server --domain test.example.com
python3 dns_automation.py --start-client --socks-port 9050
python3 dns_automation.py --test-tunnel --socks-port 9050
EOF
    chmod +x ~/rbt-dns/test-iran.sh
    
    log_success "Management scripts created"
}

# Main installation function
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    RBT DNS Manager Installer                ║"
    echo "║                                                             ║"
    echo "║  Advanced DNS Testing and Selection System for RBT Project  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    check_requirements
    install_system_deps
    install_python_deps
    install_go
    setup_dns_manager
    install_dnstt
    create_config
    create_scripts
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  Installation Completed!                    ║"
    echo "║                                                             ║"
    echo "║  Usage:                                                     ║"
    echo "║    ~/rbt-dns/test-dns.sh     - Test DNS performance        ║"
    echo "║    ~/rbt-dns/status.sh       - Show system status           ║"
    echo "║    ~/rbt-dns/start-tunnel.sh - Setup DNS tunnel          ║"
    echo "║    ~/rbt-dns/test-iran.sh    - Test Iran connectivity     ║"
    echo "║                                                             ║"
    echo "║  Systemd Service:                                           ║"
    echo "║    sudo systemctl enable rbt-dns-manager                   ║"
    echo "║    sudo systemctl start rbt-dns-manager                    ║"
    echo "║                                                             ║"
    echo "║  Configuration:                                             ║"
    echo "║    ~/rbt-dns/config/dns_config.json                        ║"
    echo "║                                                             ║"
    echo "║  Logs:                                                      ║"
    echo "║    ~/rbt-dns/logs/                                         ║"
    echo "║                                                             ║"
    echo "║  Next Steps:                                                ║"
    echo "║    1. Copy Python scripts to ~/rbt-dns/                     ║"
    echo "║    2. Configure your DNS records for tunneling            ║"
    echo "║    3. Test with: python3 dns_automation.py --init         ║"
    echo "║                                                             ║"
    echo "║  Support:                                                   ║"
    echo "║    For issues and questions, check the documentation       ║"
    echo "║    or create an issue on the GitHub repository.           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Run main function
main "$@"