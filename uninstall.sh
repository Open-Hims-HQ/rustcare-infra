#!/bin/bash
# RustCare Uninstallation Script

set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/rustcare}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

echo "=========================================="
echo "  RustCare Uninstallation"
echo "=========================================="
echo ""

# Stop and disable service
if systemctl is-active --quiet rustcare.service 2>/dev/null; then
    log_info "Stopping service..."
    systemctl stop rustcare.service
fi

if systemctl is-enabled --quiet rustcare.service 2>/dev/null; then
    log_info "Disabling service..."
    systemctl disable rustcare.service
fi

# Stop Docker containers if using Docker
if command -v docker &> /dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
        log_info "Stopping Docker containers..."
        cd "$SCRIPT_DIR"
        docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
    fi
fi

# Remove systemd service
if [[ -f /etc/systemd/system/rustcare.service ]]; then
    log_info "Removing systemd service..."
    rm /etc/systemd/system/rustcare.service
    systemctl daemon-reload
fi

# Remove binary installation (optional - commented for safety)
read -p "Remove binary installation at $INSTALL_DIR? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "Removing binary installation..."
        rm -rf "$INSTALL_DIR"
    fi
fi

# Remove data directories (optional - commented for safety)
read -p "Remove data directories (/var/lib/rustcare, /var/log/rustcare)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Removing data directories..."
    rm -rf /var/lib/rustcare
    rm -rf /var/log/rustcare
fi

# Remove user (optional)
read -p "Remove rustcare user? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if id -u rustcare > /dev/null 2>&1; then
        log_info "Removing rustcare user..."
        userdel rustcare 2>/dev/null || true
    fi
fi

log_info "Uninstallation complete!"
log_warn "Docker volumes and data were preserved for safety."

