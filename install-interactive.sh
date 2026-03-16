#!/bin/bash
# RBT Interactive Installer Wrapper
# This script provides an easy way to run the interactive installer

set -e

echo "🚀 RBT Interactive Installer"
echo "==========================="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    echo "   Visit: https://nodejs.org/"
    exit 1
fi

# Check if we're in the webapp directory or need to navigate there
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/package.json" ]]; then
    cd "$SCRIPT_DIR"
elif [[ -f "/home/user/webapp/package.json" ]]; then
    cd "/home/user/webapp"
else
    echo "❌ Could not find the webapp directory. Please run this script from the RBT project root."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [[ ! -d "node_modules" ]]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Run the interactive installer
echo "📝 Starting interactive installer..."
echo "This will guide you through the RBT setup process."
echo ""

npx tsx scripts/interactive-installer.ts

echo ""
echo "✅ Interactive installer completed!"
echo ""
echo "Next steps:"
echo "1. Run 'npm run rbt-menu' to start the RBT interactive menu"
echo "2. Or run 'rbt' to use the command-line interface"
echo ""
echo "For more information, visit: https://github.com/EHSANKiNG/RBT"