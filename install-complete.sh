#!/bin/bash

# RBT Complete Interactive Installer
# One-line installation: bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh)

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

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}     RBT Tunnel Orchestrator Installer    ${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo
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

# Function to install dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
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
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO -E bash -
        $PKG_INSTALL nodejs
    fi
    
    print_success "Dependencies installed successfully."
}

# Function to optimize system settings
optimize_system() {
    if [[ "$SKIP_SYSTEM_CONFIG" == "true" ]]; then
        print_warning "Skipping system optimization as requested."
        return
    fi
    
    print_status "Optimizing system settings for RBT..."
    
    # Create sysctl configuration
    $SUDO tee /etc/sysctl.d/99-rbt-tune.conf > /dev/null <<EOF
# RBT System Optimization
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
    
    # Apply sysctl settings
    $SUDO sysctl --system
    
    # Increase file descriptor limits
    $SUDO tee /etc/security/limits.d/99-rbt.conf > /dev/null <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
EOF
    
    print_success "System optimization completed."
}

# Function to display interactive menu
display_menu() {
    clear
    print_header
    echo -e "${CYAN}Please select an option:${NC}"
    echo
    echo -e "${WHITE}1)${NC} Quick Install (Default Settings)"
    echo -e "${WHITE}2)${NC} Custom Install (Interactive Configuration)"
    echo -e "${WHITE}3)${NC} Install Menu System Only"
    echo -e "${WHITE}4)${NC} Install RBT Binary Only"
    echo -e "${WHITE}5)${NC} System Optimization Only"
    echo -e "${WHITE}6)${NC} Uninstall RBT"
    echo -e "${WHITE}7)${NC} Update RBT"
    echo -e "${WHITE}8)${NC} Run Interactive Menu"
    echo -e "${WHITE}9)${NC} Advanced Options"
    echo -e "${WHITE}0)${NC} Exit"
    echo
    read -p "Enter your choice [0-9]: " choice
    echo
}

# Function to handle advanced options
advanced_options() {
    clear
    print_header
    echo -e "${CYAN}Advanced Options:${NC}"
    echo
    echo -e "${WHITE}1)${NC} Skip System Configuration"
    echo -e "${WHITE}2)${NC} Force Reinstall"
    echo -e "${WHITE}3)${NC} Install Development Version"
    echo -e "${WHITE}4)${NC} Custom Repository"
    echo -e "${WHITE}5)${NC} Custom Install Path"
    echo -e "${WHITE}0)${NC} Back to Main Menu"
    echo
    read -p "Enter your choice [0-5]: " advanced_choice
    
    case $advanced_choice in
        1)
            SKIP_SYSTEM_CONFIG=true
            print_status "System configuration will be skipped."
            sleep 2
            ;;
        2)
            print_status "Force reinstall enabled."
            sleep 2
            ;;
        3)
            print_status "Development version will be installed."
            sleep 2
            ;;
        4)
            read -p "Enter custom repository (user/repo): " custom_repo
            if [[ -n "$custom_repo" ]]; then
                REPO="$custom_repo"
                print_status "Using repository: $REPO"
            fi
            sleep 2
            ;;
        5)
            read -p "Enter custom install path: " custom_path
            if [[ -n "$custom_path" ]]; then
                INSTALL_PATH="$custom_path"
                print_status "Using install path: $INSTALL_PATH"
            fi
            sleep 2
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid choice. Returning to main menu."
            sleep 2
            ;;
    esac
}

# Function to run interactive installer
run_interactive_installer() {
    print_status "Running interactive installer..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download the interactive installer
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/interactive-installer.ts" -o interactive-installer.ts
    
    # Run the installer
    if command -v npx &> /dev/null; then
        npx tsx interactive-installer.ts
    else
        print_error "npx not found. Please install Node.js first."
        exit 1
    fi
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
}

# Function to run interactive menu
run_interactive_menu() {
    print_status "Launching interactive menu..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download the menu script
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/rbt-menu.ts" -o rbt-menu.ts
    
    # Run the menu
    if command -v npx &> /dev/null; then
        npx tsx rbt-menu.ts
    else
        print_error "npx not found. Please install Node.js first."
        exit 1
    fi
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
}

# Function to install RBT binary
install_rbt_binary() {
    print_status "Installing RBT binary..."
    
    # Try to download pre-built binary first
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r ".assets[] | select(.name | contains(\"linux-amd64\")) | .browser_download_url" 2>/dev/null || echo "")
    
    if [[ -n "$DOWNLOAD_URL" ]] && [[ "$DOWNLOAD_URL" != "null" ]]; then
        print_status "Downloading pre-built binary..."
        curl -L "$DOWNLOAD_URL" -o rbt
        chmod +x rbt
        $SUDO mv rbt "$INSTALL_PATH"
        print_success "RBT binary installed successfully."
    else
        print_status "Building from source..."
        
        # Install build dependencies
        $PKG_INSTALL git openssl pkg-config libssl-dev build-essential
        
        # Install Rust if not present
        if ! command -v cargo &> /dev/null; then
            print_status "Installing Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source ~/.cargo/env
        fi
        
        # Clone and build
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
        print_success "RBT binary built and installed successfully."
    fi
}

# Function to uninstall RBT
uninstall_rbt() {
    print_warning "This will completely remove RBT from your system."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    print_status "Uninstalling RBT..."
    
    # Remove binary
    $SUDO rm -f "$INSTALL_PATH"
    
    # Remove configuration
    $SUDO rm -rf /etc/rbt
    $SUDO rm -f /etc/sysctl.d/99-rbt-tune.conf
    $SUDO rm -f /etc/security/limits.d/99-rbt.conf
    
    # Remove systemd service if exists
    $SUDO systemctl stop rbt 2>/dev/null || true
    $SUDO systemctl disable rbt 2>/dev/null || true
    $SUDO rm -f /etc/systemd/system/rbt.service
    $SUDO systemctl daemon-reload
    
    # Remove repository
    $SUDO rm -rf /opt/RBT
    
    print_success "RBT has been uninstalled."
}

# Function to update RBT
update_rbt() {
    print_status "Updating RBT..."
    
    if [[ -f "$INSTALL_PATH" ]]; then
        uninstall_rbt
    fi
    
    install_rbt_binary
    print_success "RBT has been updated."
}

# Function to install menu system only
install_menu_only() {
    print_status "Installing menu system..."
    
    # Create RBT directory
    $SUDO mkdir -p /opt/rbt-menu
    
    # Download menu files
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/rbt-menu.ts" | $SUDO tee /opt/rbt-menu/rbt-menu.ts > /dev/null
    curl -sSL "https://raw.githubusercontent.com/$REPO/main/scripts/interactive-installer.ts" | $SUDO tee /opt/rbt-menu/installer.ts > /dev/null
    
    # Create wrapper script
    $SUDO tee /usr/local/bin/rbt-menu > /dev/null <<'EOF'
#!/bin/bash
cd /opt/rbt-menu
npx tsx rbt-menu.ts "$@"
EOF
    
    $SUDO chmod +x /usr/local/bin/rbt-menu
    
    print_success "Menu system installed. Run 'rbt-menu' to use it."
}

# Main installation function
main_install() {
    check_root
    detect_pkg_manager
    install_dependencies
    
    if [[ "$MENU_ONLY" == "true" ]]; then
        install_menu_only
        return
    fi
    
    optimize_system
    install_rbt_binary
    
    # Install menu system
    install_menu_only
    
    # Add to PATH if needed
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
        print_warning "Added /usr/local/bin to PATH. Please restart your shell or run: source ~/.bashrc"
    fi
    
    print_success "Installation completed successfully!"
    print_status "You can now run 'rbt' to use RBT or 'rbt-menu' for the interactive menu."
}

# Parse command line arguments
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
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --menu-only          Install menu system only"
            echo "  --skip-system-config Skip system optimization"
            echo "  --non-interactive    Run in non-interactive mode"
            echo "  --help, -h           Show this help message"
            echo
            echo "One-line installation:"
            echo "  bash <(curl -sSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install-complete.sh)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Main program
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    while true; do
        display_menu
        
        case $choice in
            1)
                main_install
                break
                ;;
            2)
                run_interactive_installer
                break
                ;;
            3)
                MENU_ONLY=true
                main_install
                break
                ;;
            4)
                install_rbt_binary
                break
                ;;
            5)
                optimize_system
                break
                ;;
            6)
                uninstall_rbt
                break
                ;;
            7)
                update_rbt
                break
                ;;
            8)
                run_interactive_menu
                break
                ;;
            9)
                advanced_options
                ;;
            0)
                print_status "Installation cancelled."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
else
    main_install
fi