#!/bin/bash
# One-line installer for RustCare
# Usage: curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install-oneline.sh | sudo bash

set -e

# Auto-detect installation method
if command -v docker &> /dev/null && (command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1); then
    METHOD="docker"
else
    METHOD="binary"
fi

echo "🚀 RustCare Quick Installer"
echo "Detected method: $METHOD"
echo ""

# Install dependencies
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq curl wget git docker.io docker-compose 2>/dev/null || apt-get install -y -qq curl wget git docker.io docker-compose-plugin
    systemctl enable --now docker 2>/dev/null || true
elif command -v yum &> /dev/null; then
    yum install -y -q curl wget git docker docker-compose
    systemctl enable --now docker
fi

# Clone and install
INSTALL_DIR="/tmp/rustcare-install-$$"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

git clone -q https://github.com/Open-Hims-HQ/rustcare-infra.git || {
    echo "❌ Failed to clone repository"
    exit 1
}

cd rustcare-infra
INSTALL_MODE="$METHOD" bash install.sh

cd /
rm -rf "$INSTALL_DIR"

echo ""
echo "✅ Installation complete!"
echo "📖 Run 'systemctl status rustcare' to check status"

