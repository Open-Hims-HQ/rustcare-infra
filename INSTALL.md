# RustCare Installation Guide

Complete installation guide for all deployment methods.

## Quick Start

### One-Line Installation

```bash
# Docker (recommended for most users)
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo INSTALL_MODE=docker bash

# Binary (for production servers)
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo INSTALL_MODE=binary bash
```

## Installation Methods

### Method 1: Docker Compose (Recommended)

**Best for:**
- Development environments
- Small to medium deployments
- Quick setup and testing
- Easy updates

**Requirements:**
- Docker 20.10+
- Docker Compose 2.0+ (or docker compose plugin)
- 4GB RAM minimum
- 20GB disk space

**Installation:**
```bash
# Clone infra repository
git clone https://github.com/Open-Hims-HQ/rustcare-infra.git
cd rustcare-infra

# Run installer
sudo INSTALL_MODE=docker ./install.sh
```

**What it does:**
1. Creates `.env` file with generated secrets
2. Pulls Docker images
3. Starts all services (PostgreSQL, Redis, Server, UI)
4. Creates systemd service for auto-start
5. Enables service on boot

**Service Management:**
```bash
# Start/Stop/Restart
sudo systemctl start rustcare
sudo systemctl stop rustcare
sudo systemctl restart rustcare

# Status
sudo systemctl status rustcare

# Logs
cd rustcare-infra
docker-compose logs -f
```

### Method 2: Binary Installation

**Best for:**
- Production servers
- High-performance requirements
- Servers without Docker
- Resource-constrained environments

**Requirements:**
- Linux (x86_64 or ARM64)
- PostgreSQL 14+ (separate installation)
- Redis 6+ (separate installation)
- 2GB RAM minimum
- 10GB disk space

**Installation Steps:**

1. **Download binary:**
   ```bash
   # Latest release
   wget https://github.com/Open-Hims-HQ/rustcare-engine/releases/latest/download/rustcare-server-linux-x86_64.tar.gz
   
   # Or specific version
   wget https://github.com/Open-Hims-HQ/rustcare-engine/releases/download/v0.1.0/rustcare-server-0.1.0-linux-x86_64.tar.gz
   ```

2. **Verify checksum:**
   ```bash
   sha256sum -c rustcare-server-*.tar.gz.sha256
   ```

3. **Extract and install:**
   ```bash
   tar -xzf rustcare-server-*.tar.gz
   cd rustcare-server-*/
   sudo ./scripts/install.sh
   ```

4. **Or use the installer:**
   ```bash
   # Place binary in /tmp/rustcare-server first
   sudo INSTALL_MODE=binary ./install.sh
   ```

**Configuration:**
```bash
sudo nano /opt/rustcare/config/config.toml
```

**Service Management:**
```bash
# Start/Stop/Restart
sudo systemctl start rustcare
sudo systemctl stop rustcare
sudo systemctl restart rustcare

# Status
sudo systemctl status rustcare

# Logs
sudo journalctl -u rustcare -f
```

### Method 3: Build from Source

**Best for:**
- Development
- Custom modifications
- Testing new features

**Requirements:**
- Rust 1.75+
- PostgreSQL development libraries
- OpenSSL development libraries

**Build:**
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install dependencies
sudo apt-get install pkg-config libssl-dev libpq-dev  # Ubuntu/Debian
sudo yum install pkgconfig openssl-devel postgresql-devel  # CentOS/RHEL

# Build
cd rustcare-engine
cargo build --release

# Install
sudo INSTALL_MODE=binary ./install.sh
```

## Post-Installation

### 1. Configure Database

**For Docker:**
```bash
cd rustcare-infra
nano .env
# Update POSTGRES_PASSWORD
```

**For Binary:**
```bash
sudo nano /opt/rustcare/config/config.toml
# Update DATABASE_URL
```

### 2. Run Migrations

```bash
# Docker
docker-compose exec rustcare-server sqlx migrate run

# Binary
export DATABASE_URL="postgresql://rustcare:password@localhost/rustcare"
sqlx migrate run
```

### 3. Start Services

```bash
sudo systemctl start rustcare
sudo systemctl enable rustcare  # Enable on boot
```

### 4. Verify Installation

```bash
# Check health
curl http://localhost:8080/health

# Check service status
sudo systemctl status rustcare
```

## Configuration

### Environment Variables

**Docker (.env file):**
```bash
POSTGRES_DB=rustcare
POSTGRES_USER=rustcare
POSTGRES_PASSWORD=your-secure-password
REDIS_URL=redis://redis:6379
JWT_SECRET=your-jwt-secret
ENCRYPTION_KEY=your-encryption-key
RUST_LOG=info
```

**Binary (config.toml):**
```toml
[database]
url = "postgresql://rustcare:password@localhost:5432/rustcare"

[server]
host = "0.0.0.0"
port = 8080

[logging]
level = "info"
```

### Security Checklist

- [ ] Change default passwords
- [ ] Generate strong JWT secret (32+ characters)
- [ ] Generate strong encryption key (32+ characters)
- [ ] Configure firewall
- [ ] Set up SSL/TLS
- [ ] Enable backups
- [ ] Review file permissions

## Troubleshooting

### Service won't start

```bash
# Check status
sudo systemctl status rustcare

# View logs
sudo journalctl -u rustcare -n 100

# Check configuration
sudo rustcare-server --check-config
```

### Database connection errors

```bash
# Test PostgreSQL connection
psql -U rustcare -d rustcare -h localhost

# Check PostgreSQL is running
sudo systemctl status postgresql

# Check firewall
sudo ufw status
```

### Port already in use

```bash
# Find process using port
sudo lsof -i :8080
sudo netstat -tulpn | grep 8080

# Kill process or change port in config
```

### Docker issues

```bash
# Check Docker status
sudo systemctl status docker

# View container logs
docker-compose logs rustcare-server

# Restart containers
docker-compose restart
```

## Uninstallation

```bash
cd rustcare-infra
sudo ./uninstall.sh
```

This will:
- Stop and disable the service
- Remove systemd service file
- Optionally remove binaries and data (with confirmation)

## Updates

### Docker Update

```bash
cd rustcare-infra
docker-compose pull
docker-compose up -d
```

### Binary Update

```bash
# Stop service
sudo systemctl stop rustcare

# Backup data
sudo tar -czf /backup/rustcare-$(date +%Y%m%d).tar.gz /opt/rustcare /var/lib/rustcare

# Download new version
wget https://github.com/Open-Hims-HQ/rustcare-engine/releases/download/vX.X.X/rustcare-server-X.X.X-linux-x86_64.tar.gz

# Extract and install
tar -xzf rustcare-server-*.tar.gz
cd rustcare-server-*/
sudo ./scripts/install.sh

# Run migrations
sqlx migrate run

# Start service
sudo systemctl start rustcare
```

## Support

- **Documentation**: https://docs.rustcare.dev
- **GitHub Issues**: https://github.com/Open-Hims-HQ/rustcare-engine/issues
- **Email**: support@rustcare.dev

