#!/bin/bash

# RustCare Infrastructure - Engine .env Generator
# Automatically generates rustcare-engine/.env with infrastructure connection details
# Author: RustCare Team
# Date: 2025-10-23

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ENGINE_DIR="$INFRA_DIR/../rustcare-engine"
INFRA_ENV="$INFRA_DIR/.env"
ENGINE_ENV="$ENGINE_DIR/.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RustCare Engine .env Generator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if infra .env exists
if [[ ! -f "$INFRA_ENV" ]]; then
    echo -e "${RED}❌ Infrastructure .env not found at: $INFRA_ENV${NC}"
    echo -e "${YELLOW}💡 Run: cd $INFRA_DIR && ./manage.sh start${NC}"
    exit 1
fi

# Source infrastructure environment
echo -e "${BLUE}📋 Loading infrastructure configuration...${NC}"
source "$INFRA_ENV"

# Get actual passwords from running Docker containers
echo -e "${BLUE}🔍 Detecting actual passwords from infrastructure...${NC}"

# Get PostgreSQL password from Docker (actual generated password)
if docker ps | grep -q rustcare-postgres; then
    DOCKER_POSTGRES_PASSWORD=$(docker exec rustcare-postgres env | grep POSTGRES_PASSWORD | cut -d'=' -f2 || echo "")
    if [[ -n "$DOCKER_POSTGRES_PASSWORD" ]] && [[ "$DOCKER_POSTGRES_PASSWORD" != "postgres" ]]; then
        POSTGRES_PASSWORD="$DOCKER_POSTGRES_PASSWORD"
        echo -e "${GREEN}✅ Detected PostgreSQL password from Docker${NC}"
    fi
fi

# Get rustcare user password from Docker logs (init script generated it)
if docker logs rustcare-postgres 2>&1 | grep -q "RUSTCARE_PASSWORD="; then
    RUSTCARE_PASSWORD=$(docker logs rustcare-postgres 2>&1 | grep "RUSTCARE_PASSWORD=" | tail -1 | cut -d'=' -f2)
    if [[ -n "$RUSTCARE_PASSWORD" ]]; then
        echo -e "${GREEN}✅ Detected rustcare user password from Docker logs${NC}"
    fi
fi

# Detect PostgreSQL port from docker-compose
PG_PORT=$(docker port rustcare-postgres 5432 2>/dev/null | cut -d':' -f2 || echo "5432")
echo -e "${GREEN}✅ PostgreSQL is running on port ${PG_PORT}${NC}"

# Generate secure passwords and keys
echo -e "${BLUE}🔐 Generating secure credentials...${NC}"

# Generate master encryption key if not exists
if [[ -z "$MASTER_ENCRYPTION_KEY" ]]; then
    MASTER_ENCRYPTION_KEY=$(openssl rand -base64 32)
    echo -e "${GREEN}✅ Generated master encryption key${NC}"
fi

# Generate database password if not set or default
if [[ -z "$POSTGRES_PASSWORD" ]] || [[ "$POSTGRES_PASSWORD" == "postgres" ]] || [[ "$POSTGRES_PASSWORD" == "change_me" ]]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo -e "${GREEN}✅ Generated PostgreSQL password${NC}"
fi

# Set default database user if not set
if [[ -z "$POSTGRES_USER" ]]; then
    POSTGRES_USER="rustcare"
fi

if [[ -z "$POSTGRES_DB" ]]; then
    POSTGRES_DB="rustcare_dev"
fi

# Generate MinIO credentials if not set or default
if [[ -z "$MINIO_ROOT_USER" ]] || [[ "$MINIO_ROOT_USER" == "minioadmin" ]]; then
    MINIO_ROOT_USER="rustcare"
fi

if [[ -z "$MINIO_ROOT_PASSWORD" ]] || [[ "$MINIO_ROOT_PASSWORD" == "minioadmin" ]]; then
    MINIO_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo -e "${GREEN}✅ Generated MinIO password${NC}"
fi

# Generate SMTP credentials if not set or default
if [[ -z "$SMTP_USERNAME" ]]; then
    SMTP_USERNAME="admin@rustcare.local"
fi

if [[ -z "$SMTP_PASSWORD" ]] || [[ "$SMTP_PASSWORD" == "changeme" ]]; then
    SMTP_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    echo -e "${GREEN}✅ Generated SMTP password${NC}"
fi

# Generate Redis password if not set
if [[ -z "$REDIS_PASSWORD" ]]; then
    REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    echo -e "${GREEN}✅ Generated Redis password${NC}"
fi

# Generate session secret
SESSION_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
echo -e "${GREEN}✅ Generated session secret${NC}"

# Generate CSRF token secret
CSRF_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo -e "${GREEN}✅ Generated CSRF secret${NC}"

# Generate JWT keys directory if needed
JWT_KEYS_DIR="$ENGINE_DIR/config/keys"
mkdir -p "$JWT_KEYS_DIR"

if [[ ! -f "$JWT_KEYS_DIR/jwt-private.pem" ]]; then
    echo -e "${BLUE}🔑 Generating JWT key pair...${NC}"
    openssl genrsa -out "$JWT_KEYS_DIR/jwt-private.pem" 2048 2>/dev/null
    openssl rsa -in "$JWT_KEYS_DIR/jwt-private.pem" -pubout -out "$JWT_KEYS_DIR/jwt-public.pem" 2>/dev/null
    chmod 600 "$JWT_KEYS_DIR/jwt-private.pem"
    chmod 644 "$JWT_KEYS_DIR/jwt-public.pem"
    echo -e "${GREEN}✅ JWT key pair generated${NC}"
fi

# Create/Update engine .env file
echo -e "${BLUE}📝 Generating rustcare-engine/.env...${NC}"

cat > "$ENGINE_ENV" << EOF
# RustCare Engine - Development Environment Configuration
# Auto-generated by rustcare-infra on $(date)
# Infrastructure connections are automatically configured

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
DATABASE_URL=postgresql://${POSTGRES_USER:-rustcare}:${RUSTCARE_PASSWORD:-${POSTGRES_PASSWORD:-postgres}}@localhost:${PG_PORT:-5433}/${POSTGRES_DB:-rustcare_dev}
DATABASE_MAX_CONNECTIONS=20
DATABASE_MIN_CONNECTIONS=5
DATABASE_ACQUIRE_TIMEOUT=30
DATABASE_IDLE_TIMEOUT=600
DATABASE_MAX_LIFETIME=1800

# =============================================================================
# REDIS CONFIGURATION (Session Storage & Caching)
# =============================================================================
REDIS_URL=redis://:${REDIS_PASSWORD}@localhost:6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_MAX_CONNECTIONS=10
REDIS_CONNECTION_TIMEOUT=5
REDIS_POOL_TIMEOUT=10
REDIS_SESSION_ENABLED=true
REDIS_SESSION_TTL=3600
REDIS_CACHE_TTL=300

# =============================================================================
# NATS CONFIGURATION (Event Bus & Messaging)
# =============================================================================
NATS_URL=nats://localhost:4222
NATS_MAX_RECONNECTS=10
NATS_RECONNECT_DELAY=2
NATS_CLUSTER_NAME=rustcare-cluster
NATS_CLIENT_ID=rustcare-engine-\${HOSTNAME:-local}
ENABLE_JETSTREAM=true
NATS_STREAM_NAME=rustcare-events
NATS_CONSUMER_NAME=rustcare-engine

# =============================================================================
# MINIO CONFIGURATION (Object Storage for Files/Attachments)
# =============================================================================
S3_ENDPOINT=http://localhost:9000
S3_REGION=us-east-1
S3_ACCESS_KEY=${MINIO_ROOT_USER:-minioadmin}
S3_SECRET_KEY=${MINIO_ROOT_PASSWORD:-minioadmin}
S3_BUCKET=rustcare-storage
S3_USE_SSL=false
S3_USE_PATH_STYLE=true
S3_MAX_FILE_SIZE=104857600
# Storage buckets
S3_BUCKET_DOCUMENTS=rustcare-documents
S3_BUCKET_IMAGES=rustcare-images
S3_BUCKET_BACKUPS=rustcare-backups

# =============================================================================
# EMAIL CONFIGURATION (Stalwart Mail Server)
# =============================================================================
SMTP_HOST=localhost
SMTP_PORT=587
SMTP_USERNAME=${SMTP_USERNAME:-admin@rustcare.local}
SMTP_PASSWORD=${SMTP_PASSWORD:-${STALWART_ADMIN_PASSWORD:-changeme}}
SMTP_FROM_EMAIL=noreply@rustcare.local
SMTP_FROM_NAME=RustCare Engine
SMTP_TLS_ENABLED=true
SMTP_START_TLS=true
EMAIL_ENABLED=true
# Email templates
EMAIL_TEMPLATE_DIR=./templates/email
EMAIL_VERIFICATION_URL=http://localhost:3000/verify
EMAIL_PASSWORD_RESET_URL=http://localhost:3000/reset-password

# =============================================================================
# TELEMETRY & OBSERVABILITY
# =============================================================================
# Jaeger Distributed Tracing
JAEGER_ENABLED=true
JAEGER_ENDPOINT=http://localhost:14268/api/traces
JAEGER_SERVICE_NAME=rustcare-engine
JAEGER_SAMPLING_RATE=1.0

# Prometheus Metrics
PROMETHEUS_ENABLED=true
PROMETHEUS_PORT=9091
PROMETHEUS_NAMESPACE=rustcare
PROMETHEUS_ENDPOINT=/metrics

# OpenTelemetry
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_SERVICE_NAME=rustcare-engine

# =============================================================================
# JWT CONFIGURATION
# =============================================================================
JWT_ACCESS_TOKEN_EXPIRY=900
JWT_REFRESH_TOKEN_EXPIRY=2592000
JWT_ISSUER=rustcare-engine
JWT_AUDIENCE=rustcare-api
JWT_ALGORITHM=RS256
JWT_PRIVATE_KEY_PATH=./config/keys/jwt-private.pem
JWT_PUBLIC_KEY_PATH=./config/keys/jwt-public.pem

# =============================================================================
# ENCRYPTION CONFIGURATION (HIPAA Compliance)
# =============================================================================
ENCRYPTION_ENABLED=true
ENCRYPTION_ALGORITHM=aes-256-gcm
MASTER_ENCRYPTION_KEY=${MASTER_ENCRYPTION_KEY}
ENCRYPTION_KEY_VERSION=1
ENABLE_ENVELOPE_ENCRYPTION=true
ENVELOPE_THRESHOLD_BYTES=1048576
# Key rotation
KEY_ROTATION_ENABLED=true
KEY_ROTATION_DAYS=90

# =============================================================================
# KEY MANAGEMENT SERVICE (KMS) CONFIGURATION
# =============================================================================
KMS_PROVIDER=none
# For production, configure AWS KMS, Azure Key Vault, or HashiCorp Vault
# KMS_PROVIDER=aws|azure|vault
# KMS_KEY_ID=your-key-id
# KMS_REGION=us-east-1

# =============================================================================
# SERVER CONFIGURATION
# =============================================================================
SERVER_HOST=0.0.0.0
SERVER_PORT=7077
SERVER_WORKERS=4
SERVER_KEEP_ALIVE=75
SERVER_REQUEST_TIMEOUT=30
SERVER_MAX_REQUEST_SIZE=10485760

# =============================================================================
# CORS CONFIGURATION
# =============================================================================
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8080
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,PATCH,OPTIONS
CORS_ALLOWED_HEADERS=Content-Type,Authorization,X-Request-ID,X-Organization-ID
CORS_MAX_AGE=3600
CORS_EXPOSE_HEADERS=X-Request-ID,X-RateLimit-Limit,X-RateLimit-Remaining

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================
RUST_LOG=info,rustcare_server=debug,sqlx=warn,tower_http=debug
LOG_FORMAT=json
LOG_OUTPUT=stdout
LOG_FILE_PATH=./logs/rustcare.log
LOG_MAX_SIZE=100MB
LOG_MAX_BACKUPS=10
LOG_COMPRESS=true

# =============================================================================
# RATE LIMITING
# =============================================================================
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=60
RATE_LIMIT_AUTH_REQUESTS_PER_MINUTE=10
RATE_LIMIT_BURST=20
RATE_LIMIT_LOCKOUT_DURATION=900

# =============================================================================
# SESSION MANAGEMENT
# =============================================================================
SESSION_SECRET=${SESSION_SECRET}
SESSION_TIMEOUT=3600
SESSION_MAX_LIFETIME=86400
SESSION_CLEANUP_INTERVAL=300
MAX_SESSIONS_PER_USER=5

# =============================================================================
# SECURITY TOKENS
# =============================================================================
CSRF_SECRET=${CSRF_SECRET}
API_KEY_SALT=$(openssl rand -base64 16)

# =============================================================================
# AUDIT & COMPLIANCE
# =============================================================================
AUDIT_ENABLED=true
AUDIT_LOG_ALL_REQUESTS=true
AUDIT_LOG_PHI_ACCESS=true
AUDIT_RETENTION_DAYS=2555
HIPAA_COMPLIANCE_MODE=true
PHI_MASKING_ENABLED=true

# =============================================================================
# DEVELOPMENT FLAGS
# =============================================================================
DEV_MODE=true
DEV_RELOAD=true
DEV_PRETTY_LOGS=true
DEV_EXPOSE_ERRORS=true
DEV_SEED_DATABASE=false

# =============================================================================
# FEATURE FLAGS
# =============================================================================
FEATURE_MFA_ENABLED=true
FEATURE_OAUTH_ENABLED=true
FEATURE_CERTIFICATE_AUTH_ENABLED=false
FEATURE_API_DOCS_ENABLED=true
FEATURE_METRICS_ENABLED=true
FEATURE_WEBHOOKS_ENABLED=true
FEATURE_WORKFLOW_ENGINE_ENABLED=true
FEATURE_PLUGIN_SYSTEM_ENABLED=false

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================
BACKUP_ENABLED=true
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=30
BACKUP_S3_BUCKET=rustcare-backups
BACKUP_COMPRESS=true
BACKUP_ENCRYPT=true

# =============================================================================
# EXTERNAL SERVICE URLS (for reference)
# =============================================================================
# Monitoring & Observability
GRAFANA_URL=http://localhost:3001
PROMETHEUS_URL=http://localhost:9090
JAEGER_UI_URL=http://localhost:16686

# Infrastructure
MINIO_CONSOLE_URL=http://localhost:9001
NATS_MONITOR_URL=http://localhost:8222
REDIS_INSIGHT_URL=http://localhost:8001

# Mail Server
STALWART_ADMIN_URL=http://localhost:8082
EOF

echo -e "${GREEN}✅ Generated $ENGINE_ENV${NC}"
echo ""

# Update infrastructure .env with generated passwords if they were auto-generated
if [[ ! -f "$INFRA_DIR/.passwords.generated" ]]; then
    echo -e "${BLUE}💾 Saving generated passwords to infrastructure .env...${NC}"
    
    # Backup original .env
    cp "$INFRA_ENV" "$INFRA_ENV.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update passwords in infrastructure .env
    sed -i.bak \
        -e "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
        -e "s|MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}|" \
        -e "s|MINIO_ROOT_USER=.*|MINIO_ROOT_USER=${MINIO_ROOT_USER}|" \
        -e "s|SMTP_PASSWORD=.*|SMTP_PASSWORD=${SMTP_PASSWORD}|" \
        -e "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=${REDIS_PASSWORD}|" \
        "$INFRA_ENV"
    
    rm -f "$INFRA_ENV.bak"
    
    # Mark passwords as generated
    touch "$INFRA_DIR/.passwords.generated"
    cat > "$INFRA_DIR/.passwords.generated" << PASS_EOF
# Auto-generated passwords - DO NOT COMMIT
# Generated on: $(date)
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
SMTP_PASSWORD=${SMTP_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
MASTER_ENCRYPTION_KEY=${MASTER_ENCRYPTION_KEY}
SESSION_SECRET=${SESSION_SECRET}
CSRF_SECRET=${CSRF_SECRET}
PASS_EOF
    
    chmod 600 "$INFRA_DIR/.passwords.generated"
    echo -e "${GREEN}✅ Passwords saved to .passwords.generated (keep this file secure!)${NC}"
fi

# Show summary
echo ""
echo -e "${BLUE}📊 Configuration Summary:${NC}"
echo -e "  Database:   postgresql://${POSTGRES_USER}:****@localhost:5432/${POSTGRES_DB}"
echo -e "  Redis:      redis://localhost:6379"
echo -e "  NATS:       nats://localhost:4222"
echo -e "  MinIO:      http://localhost:9000 (access: ${MINIO_ROOT_USER})"
echo -e "  SMTP:       localhost:587"
echo -e "  Jaeger:     http://localhost:14268"
echo -e "  Prometheus: http://localhost:9090"
echo ""

# Create logs directory
mkdir -p "$ENGINE_DIR/logs"

echo -e "${GREEN}✅ RustCare Engine .env configuration complete!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "  1. Review: ${YELLOW}$ENGINE_ENV${NC}"
echo -e "  2. Start:  ${YELLOW}cd $ENGINE_DIR && ./quick-start.sh${NC}"
echo ""
