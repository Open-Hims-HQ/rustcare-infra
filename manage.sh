#!/bin/bash

# RustCare Infrastructure Management Script
# Provides easy commands to manage the development infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo -e "${BLUE}RustCare Infrastructure Management${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  status    Show service status"
    echo "  logs      Show logs (use -f to follow)"
    echo "  clean     Stop and remove volumes (CAUTION: deletes data)"
    echo "  update    Pull latest images and restart"
    echo "  setup     Initial setup (copy .env.example)"
    echo "  passwords Manage passwords (generate|reset|show|backup)"
    echo "  health    Check health of all services"
    echo "  urls      Show service URLs"
    echo ""
    echo "Service-specific commands:"
    echo "  db        Database operations (start|stop|reset|connect)"
    echo "  cache     Redis operations (start|stop|reset|connect)"
    echo "  storage   MinIO operations (start|stop|console)"
    echo "  mail      Mail server operations (start|stop|logs|admin)"
    echo ""
    echo "Password Management:"
    echo "  passwords generate              Generate all new passwords"
    echo "  passwords reset <service>       Reset specific service password"
    echo "  passwords show                  Show current password status"
    echo "  passwords backup                Backup current passwords"
    echo ""
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        exit 1
    fi
}

setup_env() {
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        echo -e "${YELLOW}Setting up environment...${NC}"
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        echo -e "${GREEN}✅ Created .env from .env.example${NC}"
        
        echo ""
        echo -e "${BLUE}🔐 Would you like to generate secure random passwords?${NC}"
        read -p "Generate random passwords? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Skipping password generation. Please edit .env manually.${NC}"
        else
            echo -e "${BLUE}Generating secure passwords...${NC}"
            "$SCRIPT_DIR/manage-passwords.sh" generate
        fi
    else
        echo -e "${GREEN}✅ .env already exists${NC}"
        
        # Check if passwords are set
        if ! grep -q "POSTGRES_PASSWORD=" "$SCRIPT_DIR/.env" || grep -q "change_me" "$SCRIPT_DIR/.env"; then
            echo ""
            echo -e "${YELLOW}⚠️  Default passwords detected in .env${NC}"
            read -p "Generate secure passwords now? [Y/n]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                "$SCRIPT_DIR/manage-passwords.sh" generate
            fi
        fi
    fi
}

start_services() {
    echo -e "${YELLOW}Starting RustCare infrastructure...${NC}"
    
    # Check if we should capture passwords from initialization
    if [[ ! -f "$SCRIPT_DIR/.env" ]] || grep -q "change_me" "$SCRIPT_DIR/.env" 2>/dev/null; then
        echo -e "${BLUE}🔐 Starting services with password capture...${NC}"
        "$SCRIPT_DIR/capture-passwords.sh" start all
    else
        echo -e "${BLUE}Starting services with existing configuration...${NC}"
        cd "$SCRIPT_DIR"
        docker-compose up -d
    fi
    
    echo ""
    echo -e "${GREEN}✅ Infrastructure started${NC}"
    
    # Generate engine .env configuration
    if [[ -f "$SCRIPT_DIR/scripts/generate-engine-env.sh" ]]; then
        echo ""
        echo -e "${BLUE}🔧 Generating RustCare Engine configuration...${NC}"
        "$SCRIPT_DIR/scripts/generate-engine-env.sh"
    fi
    
    show_urls
}

stop_services() {
    echo -e "${YELLOW}Stopping RustCare infrastructure...${NC}"
    cd "$SCRIPT_DIR"
    docker-compose down
    echo -e "${GREEN}✅ Infrastructure stopped${NC}"
}

restart_services() {
    echo -e "${YELLOW}Restarting RustCare infrastructure...${NC}"
    cd "$SCRIPT_DIR"
    docker-compose restart
    echo -e "${GREEN}✅ Infrastructure restarted${NC}"
}

show_status() {
    echo -e "${BLUE}RustCare Infrastructure Status:${NC}"
    echo ""
    cd "$SCRIPT_DIR"
    docker-compose ps
}

show_logs() {
    cd "$SCRIPT_DIR"
    if [[ "$1" == "-f" ]]; then
        docker-compose logs -f
    else
        docker-compose logs --tail=50
    fi
}

clean_services() {
    echo -e "${RED}⚠️  This will delete ALL data in persistent volumes!${NC}"
    read -p "Are you sure? Type 'yes' to continue: " -r
    if [[ $REPLY == "yes" ]]; then
        echo -e "${YELLOW}Cleaning infrastructure...${NC}"
        cd "$SCRIPT_DIR"
        docker-compose down -v
        echo -e "${GREEN}✅ Infrastructure cleaned${NC}"
    else
        echo -e "${BLUE}Operation cancelled${NC}"
    fi
}

update_services() {
    echo -e "${YELLOW}Updating infrastructure...${NC}"
    cd "$SCRIPT_DIR"
    docker-compose pull
    docker-compose up -d
    echo -e "${GREEN}✅ Infrastructure updated${NC}"
}

check_health() {
    echo -e "${BLUE}Checking service health...${NC}"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    # Check if containers are running
    if ! docker-compose ps | grep -q "Up"; then
        echo -e "${RED}❌ Services are not running. Start with: $0 start${NC}"
        return 1
    fi
    
    # PostgreSQL
    if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL${NC}"
    else
        echo -e "${RED}❌ PostgreSQL${NC}"
    fi
    
    # Redis
    if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis${NC}"
    else
        echo -e "${RED}❌ Redis${NC}"
    fi
    
    # MinIO
    if curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        echo -e "${GREEN}✅ MinIO${NC}"
    else
        echo -e "${RED}❌ MinIO${NC}"
    fi
    
    # NATS
    if curl -f http://localhost:8222/varz >/dev/null 2>&1; then
        echo -e "${GREEN}✅ NATS${NC}"
    else
        echo -e "${RED}❌ NATS${NC}"
    fi
    
    # Jaeger
    if curl -f http://localhost:16686 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Jaeger${NC}"
    else
        echo -e "${RED}❌ Jaeger${NC}"
    fi
    
    # Prometheus
    if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Prometheus${NC}"
    else
        echo -e "${RED}❌ Prometheus${NC}"
    fi
    
    # Grafana
    if curl -f http://localhost:3001/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Grafana${NC}"
    else
        echo -e "${RED}❌ Grafana${NC}"
    fi
    
    # MailHog (dev profile)
    if docker-compose ps mailhog 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}✅ MailHog (Dev)${NC}"
    elif docker-compose --profile dev ps mailhog 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}✅ MailHog (Dev)${NC}"
    else
        echo -e "${YELLOW}⚠️  MailHog (Dev - not running)${NC}"
    fi
    
    # Stalwart Mail
    if docker-compose ps stalwart-mail 2>/dev/null | grep -q "Up"; then
        if nc -z localhost 25 2>/dev/null; then
            echo -e "${GREEN}✅ Stalwart Mail${NC}"
        else
            echo -e "${YELLOW}⚠️  Stalwart Mail (starting...)${NC}"
        fi
    else
        echo -e "${RED}❌ Stalwart Mail${NC}"
    fi
}

show_urls() {
    echo -e "${BLUE}Service URLs:${NC}"
    echo ""
    echo -e "🗄️  PostgreSQL:   ${YELLOW}postgresql://rustcare:password@localhost:5432/rustcare_dev${NC}"
    echo -e "⚡ Redis:        ${YELLOW}redis://localhost:6379${NC}"
    echo -e "📦 MinIO API:    ${YELLOW}http://localhost:9000${NC}"
    echo -e "🖥️  MinIO Console: ${YELLOW}http://localhost:9001${NC}"
    echo -e "� Stalwart Mail: ${YELLOW}http://localhost:8080${NC} (Admin Console)"
    echo -e "   SMTP:         ${YELLOW}localhost:25${NC} / ${YELLOW}localhost:587${NC} (submission)"
    echo -e "   IMAP:         ${YELLOW}localhost:993${NC} (SSL)"
    echo -e "📧 MailHog (Dev): ${YELLOW}http://localhost:8025${NC} (SMTP: localhost:1025)"
    echo -e "�📡 NATS:         ${YELLOW}nats://localhost:4222${NC}"
    echo -e "🔍 Jaeger:       ${YELLOW}http://localhost:16686${NC}"
    echo -e "📊 Prometheus:   ${YELLOW}http://localhost:9090${NC}"
    echo -e "📈 Grafana:      ${YELLOW}http://localhost:3001${NC} (admin/rustcare_grafana_password)"
    echo -e "📧 MailHog (Dev): ${YELLOW}http://localhost:8025${NC}"
    echo ""
}

# Database operations
db_operations() {
    case "$1" in
        start)
            echo -e "${YELLOW}Starting PostgreSQL...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose up -d postgres
            ;;
        stop)
            echo -e "${YELLOW}Stopping PostgreSQL...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose stop postgres
            ;;
        reset)
            echo -e "${RED}⚠️  This will delete ALL PostgreSQL data!${NC}"
            read -p "Are you sure? Type 'yes' to continue: " -r
            if [[ $REPLY == "yes" ]]; then
                cd "$SCRIPT_DIR"
                docker-compose stop postgres
                docker volume rm rustcare-infra_postgres_data || true
                docker-compose up -d postgres
                echo -e "${GREEN}✅ PostgreSQL reset${NC}"
                
                # Wait for PostgreSQL to be ready
                echo -e "${BLUE}⏳ Waiting for PostgreSQL to initialize...${NC}"
                sleep 5
                
                # Generate new .env file for rustcare-engine with updated passwords
                if [[ -f "$SCRIPT_DIR/scripts/generate-engine-env.sh" ]]; then
                    echo -e "${BLUE}🔧 Regenerating RustCare Engine configuration...${NC}"
                    "$SCRIPT_DIR/scripts/generate-engine-env.sh"
                    echo -e "${GREEN}✅ Engine .env updated with new database password${NC}"
                fi
            fi
            ;;
        connect)
            echo -e "${BLUE}Connecting to PostgreSQL...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose exec postgres psql -U rustcare -d rustcare_dev
            ;;
        *)
            echo "Usage: $0 db [start|stop|reset|connect]"
            ;;
    esac
}

# Cache operations
cache_operations() {
    case "$1" in
        start)
            echo -e "${YELLOW}Starting Redis...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose up -d redis
            ;;
        stop)
            echo -e "${YELLOW}Stopping Redis...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose stop redis
            ;;
        reset)
            echo -e "${RED}⚠️  This will delete ALL Redis data!${NC}"
            read -p "Are you sure? Type 'yes' to continue: " -r
            if [[ $REPLY == "yes" ]]; then
                cd "$SCRIPT_DIR"
                docker-compose stop redis
                docker volume rm rustcare-infra_redis_data || true
                docker-compose up -d redis
                echo -e "${GREEN}✅ Redis reset${NC}"
            fi
            ;;
        connect)
            echo -e "${BLUE}Connecting to Redis...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose exec redis redis-cli
            ;;
        *)
            echo "Usage: $0 cache [start|stop|reset|connect]"
            ;;
    esac
}

# Storage operations
storage_operations() {
    case "$1" in
        start)
            echo -e "${YELLOW}Starting MinIO...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose up -d minio
            ;;
        stop)
            echo -e "${YELLOW}Stopping MinIO...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose stop minio
            ;;
        console)
            echo -e "${BLUE}Opening MinIO console...${NC}"
            open http://localhost:9001 || echo "Visit: http://localhost:9001"
            ;;
        *)
            echo "Usage: $0 storage [start|stop|console]"
            ;;
    esac
}

# Mail operations
mail_operations() {
    case "$1" in
        start)
            echo -e "${YELLOW}Starting Stalwart Mail Server...${NC}"
            cd "$SCRIPT_DIR"
            # Generate certificates if they don't exist
            if [[ ! -f "certs/cert.pem" ]]; then
                echo -e "${BLUE}Generating certificates...${NC}"
                ./certs/generate-certs.sh
            fi
            docker-compose up -d stalwart-mail
            ;;
        stop)
            echo -e "${YELLOW}Stopping Stalwart Mail Server...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose stop stalwart-mail
            ;;
        logs)
            echo -e "${BLUE}Showing Stalwart Mail logs...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose logs -f stalwart-mail
            ;;
        admin)
            echo -e "${BLUE}Opening Stalwart Admin Console...${NC}"
            echo -e "${YELLOW}Default credentials: admin@rustcare.local / admin123${NC}"
            open http://localhost:8080 || echo "Visit: http://localhost:8080"
            ;;
        dev)
            echo -e "${YELLOW}Starting MailHog for development...${NC}"
            cd "$SCRIPT_DIR"
            docker-compose --profile dev up -d mailhog
            ;;
        *)
            echo "Usage: $0 mail [start|stop|logs|admin|dev]"
            echo ""
            echo "Commands:"
            echo "  start - Start Stalwart Mail Server (production-ready)"
            echo "  stop  - Stop Stalwart Mail Server"
            echo "  logs  - Show mail server logs"
            echo "  admin - Open admin console"
            echo "  dev   - Start MailHog for development"
            ;;
    esac
}

# Main command handling
check_docker

case "${1:-}" in
    start)
        setup_env
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    clean)
        clean_services
        ;;
    update)
        update_services
        ;;
    setup)
        setup_env
        ;;
    health)
        check_health
        ;;
    urls)
        show_urls
        ;;
    db)
        db_operations "$2"
        ;;
    cache)
        cache_operations "$2"
        ;;
    storage)
        storage_operations "$2"
        ;;
    mail)
        mail_operations "$2"
        ;;
    passwords)
        "$SCRIPT_DIR/manage-passwords.sh" "$2" "$3"
        ;;
    *)
        usage
        exit 1
        ;;
esac