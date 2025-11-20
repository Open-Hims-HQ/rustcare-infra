# RustCare Quick Start

Get RustCare running in one command!

## One-Command Installation

### Docker (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo INSTALL_MODE=docker bash
```

### Binary
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo INSTALL_MODE=binary bash
```

### Auto-detect
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Hims-HQ/rustcare-infra/main/install.sh | sudo bash
```

## What Gets Installed

✅ **RustCare Server** - Backend API (port 8080)  
✅ **RustCare UI** - Frontend (port 3000)  
✅ **PostgreSQL** - Database (port 5432)  
✅ **Redis** - Cache (port 6379)  
✅ **Systemd Service** - Auto-start on boot  
✅ **Health Checks** - Automatic monitoring  

## After Installation

1. **Check status:**
   ```bash
   sudo systemctl status rustcare
   ```

2. **View logs:**
   ```bash
   # Docker
   cd rustcare-infra && docker-compose logs -f
   
   # Binary
   sudo journalctl -u rustcare -f
   ```

3. **Access services:**
   - API: http://localhost:8080
   - UI: http://localhost:3000
   - Health: http://localhost:8080/health

4. **Configure:**
   ```bash
   # Docker
   nano rustcare-infra/.env
   
   # Binary
   sudo nano /opt/rustcare/config/config.toml
   ```

## Service Management

```bash
# Start
sudo systemctl start rustcare

# Stop
sudo systemctl stop rustcare

# Restart
sudo systemctl restart rustcare

# Status
sudo systemctl status rustcare

# Enable on boot
sudo systemctl enable rustcare
```

## Uninstall

```bash
cd rustcare-infra
sudo ./uninstall.sh
```

## Troubleshooting

**Service won't start:**
```bash
sudo systemctl status rustcare
sudo journalctl -u rustcare -n 50
```

**Port already in use:**
```bash
sudo lsof -i :8080
# Change port in config or stop conflicting service
```

**Docker issues:**
```bash
sudo systemctl status docker
docker ps
docker-compose logs
```

## Next Steps

1. Configure database connection
2. Run migrations: `sqlx migrate run`
3. Create your first organization
4. Set up users and permissions
5. Configure SSL/TLS for production

For detailed documentation, see [INSTALL.md](INSTALL.md)

