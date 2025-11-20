#!/bin/bash
# Quick Install Script - One command installation
# Usage: curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/quick-install.sh | bash

set -e

INSTALL_MODE="${1:-docker}"

log_info() {
    echo "✓ $1"
}

log_error() {
    echo "✗ $1" >&2
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Usage: sudo bash <(curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/quick-install.sh) [docker|binary]"
    exit 1
fi

# Install dependencies
log_info "Installing dependencies..."

if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y curl wget docker.io docker-compose || apt-get install -y curl wget docker.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
elif command -v yum &> /dev/null; then
    yum install -y curl wget docker docker-compose
    systemctl enable docker
    systemctl start docker
elif command -v dnf &> /dev/null; then
    dnf install -y curl wget docker docker-compose
    systemctl enable docker
    systemctl start docker
else
    log_error "Unsupported package manager. Please install Docker manually."
    exit 1
fi

# Clone repositories
INSTALL_DIR="/opt/rustcare-install"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [[ ! -d "rustcare-infra" ]]; then
    log_info "Cloning repositories..."
    git clone https://github.com/Open-Hims-HQ/rustcare-infra.git || {
        log_error "Failed to clone repository. Please clone manually."
        exit 1
    }
fi

cd rustcare-infra

# Run installation
log_info "Running installation..."
INSTALL_MODE="$INSTALL_MODE" bash install.sh

log_info "Installation complete!"
echo ""
echo "RustCare is now installed and running."
echo "Access the API at: http://localhost:8080"
echo "Access the UI at: http://localhost:3000"

