# RustCare Infrastructure

Infrastructure configuration and deployment files for RustCare Healthcare Platform.

## Quick Installation

### One-Command Install (Recommended)

**For Docker (Recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo INSTALL_MODE=docker bash
```

**For Binary Installation:**
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo INSTALL_MODE=binary bash
```

**Auto-detect (Docker if available, otherwise binary):**
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo bash
```

The installer will:
- ✅ Detect your environment automatically
- ✅ Install all dependencies
- ✅ Set up as a systemd daemon service
- ✅ Configure and start all services
- ✅ Provide next steps

### Manual Installation

1. **Clone repositories:**
   ```bash
   git clone https://github.com/Open-Hims-HQ/rustcare-engine.git
   git clone https://github.com/Open-Hims-HQ/rustcare-ui.git
   git clone https://github.com/Open-Hims-HQ/rustcare-infra.git
   ```

2. **Run installer:**
   ```bash
   cd rustcare-infra
   sudo ./install.sh
   ```

## Installation Methods

### Docker Compose (Default)

Automatically detects Docker and installs as a systemd service:

```bash
sudo INSTALL_MODE=docker ./install.sh
```

**Features:**
- All services in containers (PostgreSQL, Redis, Server, UI)
- Automatic service management
- Easy updates and rollbacks
- Isolated environment

### Binary Installation

For servers without Docker or for production deployments:

```bash
sudo INSTALL_MODE=binary ./install.sh
```

**Features:**
- Native binary performance
- Systemd service integration
- Lower resource usage
- Direct system integration

## Directory Structure

```
projects/
├── rustcare-engine/     # Backend source code
├── rustcare-ui/         # Frontend source code
└── rustcare-infra/      # Infrastructure configs
    ├── docker-compose.yml
    ├── install.sh       # Main installer
    ├── uninstall.sh     # Uninstaller
    └── quick-install.sh # One-command installer
```

## Services

The installation includes:

- **PostgreSQL** - Database (port 5432)
- **Redis** - Cache and sessions (port 6379)
- **RustCare Server** - Backend API (port 8080)
- **RustCare UI** - Frontend (port 3000)
- **Caddy** - Reverse proxy (optional, ports 80/443)

## Configuration

### Docker Installation

Edit `.env` file:
```bash
cd rustcare-infra
nano .env
```

### Binary Installation

Edit configuration:
```bash
sudo nano /opt/rustcare/config/config.toml
```

## Service Management

### Start Service
```bash
sudo systemctl start rustcare
```

### Stop Service
```bash
sudo systemctl stop rustcare
```

### Status
```bash
sudo systemctl status rustcare
```

### Logs

**Docker:**
```bash
cd rustcare-infra
docker-compose logs -f
```

**Binary:**
```bash
sudo journalctl -u rustcare -f
```

## Updates

### Docker
```bash
cd rustcare-infra
docker-compose pull
docker-compose up -d
```

### Binary
```bash
# Download new release
wget https://github.com/Open-Hims-HQ/rustcare-engine/releases/download/vX.X.X/rustcare-server-X.X.X-linux-x86_64.tar.gz

# Extract and install
tar -xzf rustcare-server-*.tar.gz
cd rustcare-server-*/
sudo ./scripts/install.sh
```

## Uninstallation

```bash
cd rustcare-infra
sudo ./uninstall.sh
```

## Troubleshooting

### Service won't start
```bash
sudo systemctl status rustcare
sudo journalctl -u rustcare -n 50
```

### Docker issues
```bash
docker-compose ps
docker-compose logs
```

### Port conflicts
Check what's using the ports:
```bash
sudo netstat -tulpn | grep -E ':(5432|6379|8080|3000)'
```

## Production Deployment

For production, ensure:

1. **Change default passwords** in `.env` or config
2. **Set up SSL/TLS** with Caddy or Nginx
3. **Configure backups** for PostgreSQL
4. **Set up monitoring** (Prometheus/Grafana)
5. **Enable firewall** rules
6. **Review security** settings

## Support

- Documentation: https://docs.rustcare.dev
- Issues: https://github.com/Open-Hims-HQ/rustcare-engine/issues
- Email: support@rustcare.dev
