#!/bin/bash
set -e

echo "🚀 Starting RBT Ultimate Installer..."

# Helper for sudo
SUDO=''
if (( $EUID != 0 )); then
    SUDO='sudo'
fi

# 1. Install System Dependencies
echo "📦 Installing system dependencies..."
if [ -f /etc/debian_version ]; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y curl jq
elif [ -f /etc/redhat-release ]; then
    $SUDO yum install -y curl jq
fi

# 2. OS Network Tuning (BBR & Buffers)
echo "🚀 Optimizing Linux Kernel for High-Performance Networking (BBR, TCP Buffers)..."
cat <<EOF | $SUDO tee /etc/sysctl.d/99-rbt-tune.conf
# Max open files
fs.file-max = 1048576

# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Tune TCP buffers for high bandwidth-delay environments
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Fast open and reuse
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
EOF
$SUDO sysctl --system

# 3. Download Pre-built Binary or Fallback to Source
INSTALL_PATH="/usr/local/bin/rbt"
REPO="EHSANKiNG/RBT"

echo "🔍 Checking for pre-built binaries..."
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep "browser_download_url.*rbt-linux-amd64" | cut -d '"' -f 4)

if [ -n "$DOWNLOAD_URL" ]; then
    echo "⚡ Found pre-built binary! Downloading..."
    echo "⬇️  URL: $DOWNLOAD_URL"
    $SUDO curl -L -o "$INSTALL_PATH" "$DOWNLOAD_URL"
    $SUDO chmod +x "$INSTALL_PATH"
    echo "✅ RBT installed successfully in seconds!"
else
    echo "⚠️  No pre-built binary found for the latest release."
    echo "🔨 Falling back to compiling from source (this may take a few minutes)..."
    
    if [ -f /etc/debian_version ]; then
        $SUDO apt-get install -y git openssl ca-certificates pkg-config libssl-dev build-essential
    elif [ -f /etc/redhat-release ]; then
        $SUDO yum install -y git openssl ca-certificates pkgconfig openssl-devel gcc
    fi

    if ! command -v cargo &> /dev/null; then
        echo "🦀 Installing Rust compiler..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    REPO_DIR="/opt/RBT"
    if [ -d "$REPO_DIR" ]; then
        $SUDO chown -R $USER "$REPO_DIR"
        cd "$REPO_DIR"
        git pull origin main
    else
        $SUDO mkdir -p /opt
        $SUDO chown $USER /opt
        git clone https://github.com/EHSANKiNG/RBT.git "$REPO_DIR"
        cd "$REPO_DIR"
    fi

    cargo build --release --bin rbt-cli
    $SUDO cp "$REPO_DIR/target/release/rbt-cli" "$INSTALL_PATH"
    $SUDO chmod +x "$INSTALL_PATH"
    echo "✅ RBT compiled and installed successfully!"
fi

echo "👉 Just type 'rbt' to open the interactive menu."

# Path Check
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    echo "⚠️  Note: Please add /usr/local/bin to your PATH or run: export PATH=\$PATH:/usr/local/bin"
fi
