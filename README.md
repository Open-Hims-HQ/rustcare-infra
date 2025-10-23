# RustCare Infrastructure

Complete Docker Compose setup for RustCare external services including PostgreSQL, Redis, MinIO, monitoring, and more.

## Quick Start

1. **Clone and setup:**
   ```bash
   cd rustcare-infra
   cp .env.example .env
   # Edit .env with your preferred passwords
   ```

2. **Start all services:**
   ```bash
   docker-compose up -d
   ```

3. **Verify services:**
   ```bash
   docker-compose ps
   ```

## Services Included

### Core Services
- **PostgreSQL 16** - Primary database with extensions
  - Port: 5432
  - Databases: `rustcare_dev`, `rustcare_test`
  - User: `rustcare`
  - Extensions: uuid-ossp, pgcrypto, pg_trgm, etc.

- **Redis 7** - Cache and session store
  - Port: 6379
  - Optimized configuration
  - AOF persistence enabled

- **MinIO** - S3-compatible object storage
  - API Port: 9000
  - Console Port: 9001
  - Credentials: rustcare/rustcare_minio_password

### Messaging & Events
- **NATS** - Message broker with JetStream
  - Port: 4222
  - Monitoring: 8222

### Email Services
- **Stalwart Mail** - Production-ready mail server
  - SMTP: 25, 587 (submission), 465 (SSL)
  - IMAP: 993 (SSL)
  - POP3: 995 (SSL)
  - Admin Console: 8080
  - PostgreSQL backend with full email capabilities

- **MailHog** - Email testing (development only)
  - SMTP Port: 1025
  - Web UI: 8025
  - Profile: `dev` (use `--profile dev` to start)
### Monitoring & Observability
- **Jaeger** - Distributed tracing
  - UI Port: 16686
  - OTLP gRPC: 4317
  - OTLP HTTP: 4318

- **Prometheus** - Metrics collection
  - Port: 9090
  - Scrapes RustCare app metrics

- **Grafana** - Dashboards and visualization  
  - Port: 3001
  - Credentials: admin/rustcare_grafana_password

### Development Tools

## Service URLs

After starting with `docker-compose up -d`:

| Service | URL | Credentials |
|---------|-----|-------------|
| PostgreSQL | `postgresql://rustcare:password@localhost:5432/rustcare_dev` | rustcare/rustcare_dev_password |
| Redis | `redis://localhost:6379` | - |
| MinIO API | `http://localhost:9000` | rustcare/rustcare_minio_password |
| MinIO Console | `http://localhost:9001` | rustcare/rustcare_minio_password |
| NATS | `nats://localhost:4222` | - |
| Stalwart Mail Admin | `http://localhost:8080` | admin@rustcare.local/admin123 |
| Stalwart SMTP | `smtp://localhost:25` | - |
| Stalwart SMTP (Auth) | `smtp://localhost:587` | user@rustcare.local/password |
| Stalwart IMAP | `imap://localhost:993` | user@rustcare.local/password |
| Jaeger UI | `http://localhost:16686` | - |
| Prometheus | `http://localhost:9090` | - |
| Grafana | `http://localhost:3001` | admin/rustcare_grafana_password |
| MailHog | `http://localhost:8025` | - |

## Commands

```bash
# Start all services (production mode)
docker-compose up -d

# Start with development email (MailHog instead of Stalwart)
docker-compose --profile dev up -d

# Stop all services
docker-compose down

# Start specific services
./manage.sh mail start    # Start Stalwart Mail
./manage.sh mail dev      # Start MailHog for development
./manage.sh mail admin    # Open mail admin console

# View logs
docker-compose logs -f stalwart-mail

# Restart specific service
docker-compose restart postgres

# Update and restart
docker-compose pull && docker-compose up -d

# Clean volumes (CAUTION: deletes all data)
docker-compose down -v
```

## Health Checks

All services include health checks. Check status:

```bash
# View health status
docker-compose ps

# Check specific service logs
docker-compose logs postgres
docker-compose logs redis
```

## Data Persistence

Persistent volumes:
- `postgres_data` - PostgreSQL data
- `redis_data` - Redis data  
- `minio_data` - MinIO data
- `stalwart_data` - Stalwart mail data
- `prometheus_data` - Prometheus metrics
- `grafana_data` - Grafana dashboards

## Production Notes

1. **Security**: Change all default passwords in `.env`
2. **Networking**: Adjust ports if needed
3. **Resources**: Monitor resource usage with Prometheus/Grafana
4. **Backups**: Set up regular backups for persistent volumes
5. **SSL**: Add SSL certificates for production deployments

## Troubleshooting

### PostgreSQL Issues
```bash
# Check logs
docker-compose logs postgres

# Connect to database
docker-compose exec postgres psql -U rustcare -d rustcare_dev

# Reset PostgreSQL data (CAUTION)
docker-compose down
docker volume rm rustcare-infra_postgres_data
docker-compose up -d postgres
```

### Redis Issues
```bash
# Check Redis connectivity
docker-compose exec redis redis-cli ping

# View Redis info
docker-compose exec redis redis-cli info
```

### MinIO Issues
```bash
# Check MinIO status
curl http://localhost:9000/minio/health/live

# Access MinIO console
open http://localhost:9001
```

### Mail Server Issues
```bash
# Check Stalwart Mail logs
docker-compose logs stalwart-mail

# Test SMTP connection
telnet localhost 25

# Check mail server status
./manage.sh mail admin

# Generate new certificates
./certs/generate-certs.sh

# Use development mail server instead
./manage.sh mail dev
```

## Integration with RustCare Engine

1. **Database Setup**: Run the database setup script from rustcare-engine:
   ```bash
   cd ../rustcare-engine
   ./scripts/setup-database.sh
   ```

2. **Environment Variables**: The engine will automatically detect running services on localhost

3. **Development Workflow**:
   ```bash
   # Terminal 1: Start infrastructure
   cd rustcare-infra && docker-compose up -d
   
   # Terminal 2: Run application
   cd rustcare-engine && cargo run --bin rustcare-server
   ```