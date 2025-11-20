#!/bin/bash
# RustCare Installation Script
# One-command installation for Docker, binary, or daemon service
# Supports: Docker Compose, Binary Installation, Systemd Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_MODE="${INSTALL_MODE:-auto}"
INSTALL_DIR="${INSTALL_DIR:-/opt/rustcare}"
SERVICE_USER="${SERVICE_USER:-rustcare}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect installation method
detect_method() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        echo "docker"
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo "docker"
    else
        echo "binary"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Install Docker Compose setup
install_docker() {
    log_info "Installing RustCare with Docker Compose..."
    
    # Check if docker-compose.yml exists
    if [[ ! -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Create .env if it doesn't exist
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        log_info "Creating .env file from template..."
        if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
            log_warn "Please edit $SCRIPT_DIR/.env with your configuration"
        else
            log_warn ".env.example not found, creating basic .env"
            cat > "$SCRIPT_DIR/.env" <<EOF
POSTGRES_DB=rustcare
POSTGRES_USER=rustcare
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
EOF
        fi
    fi
    
    # Pull and start services
    log_info "Starting Docker services..."
    cd "$SCRIPT_DIR"
    docker-compose pull || docker compose pull
    docker-compose up -d || docker compose up -d
    
    # Create systemd service for docker-compose
    log_info "Creating systemd service..."
    cat > /etc/systemd/system/rustcare.service <<EOF
[Unit]
Description=RustCare Healthcare Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Use docker compose if docker-compose not available
    if ! command -v docker-compose &> /dev/null; then
        sed -i 's|docker-compose|docker compose|g' /etc/systemd/system/rustcare.service
    fi
    
    systemctl daemon-reload
    systemctl enable rustcare.service
    
    log_info "Docker installation complete!"
    log_info "Services are starting. Check status with: systemctl status rustcare"
    log_info "View logs with: docker-compose logs -f"
}

# Install binary setup
install_binary() {
    log_info "Installing RustCare Binary..."
    
    # Check if binary exists
    BINARY_PATH=""
    if [[ -f "$SCRIPT_DIR/../rustcare-engine/target/release/rustcare-server" ]]; then
        BINARY_PATH="$SCRIPT_DIR/../rustcare-engine/target/release/rustcare-server"
    elif [[ -f "/tmp/rustcare-server" ]]; then
        BINARY_PATH="/tmp/rustcare-server"
    else
        log_error "RustCare binary not found. Please build it first or download from releases."
        log_info "To build: cd rustcare-engine && cargo build --release"
        exit 1
    fi
    
    # Create directories
    log_info "Creating directories..."
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/migrations"
    mkdir -p /var/lib/rustcare
    mkdir -p /var/log/rustcare
    
    # Copy binary
    log_info "Installing binary..."
    cp "$BINARY_PATH" "$INSTALL_DIR/bin/rustcare-server"
    chmod +x "$INSTALL_DIR/bin/rustcare-server"
    
    # Copy config and migrations
    if [[ -d "$SCRIPT_DIR/../rustcare-engine/config" ]]; then
        cp -r "$SCRIPT_DIR/../rustcare-engine/config"/* "$INSTALL_DIR/config/" 2>/dev/null || true
    fi
    
    if [[ -d "$SCRIPT_DIR/../rustcare-engine/migrations" ]]; then
        cp -r "$SCRIPT_DIR/../rustcare-engine/migrations" "$INSTALL_DIR/"
    fi
    
    # Create user if it doesn't exist
    if ! id -u "$SERVICE_USER" > /dev/null 2>&1; then
        log_info "Creating $SERVICE_USER user..."
        useradd -r -s /bin/false -d /var/lib/rustcare -c "RustCare Server" "$SERVICE_USER"
    fi
    
    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" /var/lib/rustcare
    chown -R "$SERVICE_USER:$SERVICE_USER" /var/log/rustcare
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    
    # Create systemd service
    log_info "Creating systemd service..."
    cat > /etc/systemd/system/rustcare.service <<EOF
[Unit]
Description=RustCare Healthcare Server
After=network.target postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/rustcare-server
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rustcare-server

# Environment variables
EnvironmentFile=-$INSTALL_DIR/config/.env
Environment="RUST_LOG=info"

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/rustcare /var/log/rustcare $INSTALL_DIR

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Create default config if it doesn't exist
    if [[ ! -f "$INSTALL_DIR/config/config.toml" ]]; then
        log_info "Creating default configuration..."
        cat > "$INSTALL_DIR/config/config.toml" <<EOF
[database]
url = "postgresql://rustcare:changeme@localhost:5432/rustcare"
max_connections = 20
min_connections = 5

[server]
host = "0.0.0.0"
port = 8080
workers = 4

[redis]
url = "redis://localhost:6379"

[logging]
level = "info"
format = "json"

[security]
jwt_secret = "changeme-generate-strong-random-key"
encryption_key = "changeme-generate-strong-random-key"
EOF
        log_warn "Please update $INSTALL_DIR/config/config.toml with your actual configuration"
    fi
    
    # Create .env file for environment variables
    if [[ ! -f "$INSTALL_DIR/config/.env" ]]; then
        log_info "Creating environment file..."
        cat > "$INSTALL_DIR/config/.env" <<EOF
DATABASE_URL=postgresql://rustcare:changeme@localhost:5432/rustcare
REDIS_URL=redis://localhost:6379
RUST_LOG=info
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
EOF
        log_warn "Generated secrets in $INSTALL_DIR/config/.env - keep this file secure!"
    fi
    
    systemctl daemon-reload
    systemctl enable rustcare.service
    
    log_info "Binary installation complete!"
    log_info "Edit configuration: $INSTALL_DIR/config/config.toml"
    log_info "Start service: systemctl start rustcare"
    log_info "Check status: systemctl status rustcare"
}

# Download binary from releases
download_binary() {
    VERSION="${VERSION:-latest}"
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    log_info "Downloading RustCare binary (version: $VERSION, arch: $ARCH, os: $OS)..."
    
    if [[ "$VERSION" == "latest" ]]; then
        RELEASE_URL="https://github.com/Open-Hims-HQ/rustcare-engine/releases/latest/download/rustcare-server-${OS}-${ARCH}.tar.gz"
    else
        RELEASE_URL="https://github.com/Open-Hims-HQ/rustcare-engine/releases/download/${VERSION}/rustcare-server-${VERSION}-${OS}-${ARCH}.tar.gz"
    fi
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if command -v wget &> /dev/null; then
        wget -q "$RELEASE_URL" -O rustcare-server.tar.gz || {
            log_error "Failed to download binary. Building from source instead..."
            return 1
        }
    elif command -v curl &> /dev/null; then
        curl -sL "$RELEASE_URL" -o rustcare-server.tar.gz || {
            log_error "Failed to download binary. Building from source instead..."
            return 1
        }
    else
        log_error "Neither wget nor curl found. Cannot download binary."
        return 1
    fi
    
    tar -xzf rustcare-server.tar.gz
    cp rustcare-server-*/bin/rustcare-server /tmp/rustcare-server
    chmod +x /tmp/rustcare-server
    
    log_info "Binary downloaded successfully"
    return 0
}

# Main installation function
main() {
    echo "=========================================="
    echo "  RustCare Installation Script"
    echo "=========================================="
    echo ""
    
    # Determine installation method
    if [[ "$INSTALL_MODE" == "auto" ]]; then
        INSTALL_MODE=$(detect_method)
        log_info "Auto-detected installation method: $INSTALL_MODE"
    fi
    
    case "$INSTALL_MODE" in
        docker|docker-compose)
            check_root
            install_docker
            ;;
        binary|service)
            check_root
            # Try to download binary first
            if ! download_binary 2>/dev/null; then
                log_warn "Binary download failed, using local binary if available"
            fi
            install_binary
            ;;
        *)
            log_error "Unknown installation method: $INSTALL_MODE"
            log_info "Available methods: docker, binary, auto"
            exit 1
            ;;
    esac
    
    echo ""
    log_info "✅ Installation complete!"
    echo ""
    log_info "📋 Next steps:"
    echo "  1. Configure your environment:"
    if [[ "$INSTALL_MODE" == "docker" ]]; then
        echo "     - Edit $SCRIPT_DIR/.env"
        echo "     - Then restart: sudo systemctl restart rustcare"
    else
        echo "     - Edit $INSTALL_DIR/config/config.toml"
        echo "     - Edit $INSTALL_DIR/config/.env (secrets already generated)"
    fi
    echo "  2. Start the service:"
    echo "     - sudo systemctl start rustcare"
    echo "  3. Check status:"
    echo "     - sudo systemctl status rustcare"
    echo "  4. View logs:"
    if [[ "$INSTALL_MODE" == "docker" ]]; then
        echo "     - cd $SCRIPT_DIR && docker-compose logs -f"
    else
        echo "     - sudo journalctl -u rustcare -f"
    fi
    echo "  5. Access services:"
    echo "     - API: http://localhost:8080"
    echo "     - UI: http://localhost:3000"
    echo "     - Health: http://localhost:8080/health"
    echo ""
    log_info "📖 For more information, see:"
    echo "     - README.md - Overview and quick start"
    echo "     - INSTALL.md - Detailed installation guide"
    echo "     - QUICKSTART.md - Quick reference"
}

# Run main function
main "$@"

