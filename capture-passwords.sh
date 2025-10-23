#!/bin/bash

# Password Capture and Update System for RustCare Infrastructure
# This script captures passwords generated during service initialization
# and automatically updates the .env file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
TEMP_PASSWORDS_FILE="/tmp/rustcare-generated-passwords.env"

# Function to update .env file with new password
update_env_password() {
    local key="$1"
    local value="$2"
    
    if [[ -f "$ENV_FILE" ]]; then
        if grep -q "^${key}=" "$ENV_FILE"; then
            # Update existing key
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
            else
                sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
            fi
            echo -e "${GREEN}✓ Updated ${key} in .env${NC}"
        else
            # Add new key
            echo "${key}=${value}" >> "$ENV_FILE"
            echo -e "${GREEN}✓ Added ${key} to .env${NC}"
        fi
    else
        echo -e "${RED}❌ .env file not found${NC}"
        return 1
    fi
}

# Function to capture passwords from Docker container logs
capture_docker_passwords() {
    local container_name="$1"
    local timeout=${2:-30}
    
    echo -e "${BLUE}🔍 Capturing passwords from ${container_name}...${NC}"
    
    local end_time=$((SECONDS + timeout))
    local passwords_found=false
    
    while [[ $SECONDS -lt $end_time ]]; do
        if docker logs "$container_name" 2>&1 | grep -q "RUSTCARE_INIT_PASSWORDS_START"; then
            # Extract passwords from logs
            local password_block=$(docker logs "$container_name" 2>&1 | sed -n '/RUSTCARE_INIT_PASSWORDS_START/,/RUSTCARE_INIT_PASSWORDS_END/p')
            
            echo "$password_block" | while IFS='=' read -r key value; do
                case "$key" in
                    RUSTCARE_PASSWORD)
                        update_env_password "POSTGRES_PASSWORD" "$value"
                        update_env_password "RUSTCARE_DB_PASSWORD" "$value"
                        ;;
                    STALWART_PASSWORD)
                        update_env_password "STALWART_PASSWORD" "$value"
                        ;;
                    MINIO_PASSWORD)
                        update_env_password "MINIO_ROOT_PASSWORD" "$value"
                        ;;
                    REDIS_PASSWORD)
                        update_env_password "REDIS_PASSWORD" "$value"
                        ;;
                    *)
                        if [[ "$key" =~ _PASSWORD$ ]] && [[ -n "$value" ]]; then
                            update_env_password "$key" "$value"
                        fi
                        ;;
                esac
            done
            
            passwords_found=true
            break
        fi
        sleep 1
    done
    
    if [[ "$passwords_found" == "false" ]]; then
        echo -e "${YELLOW}⚠️  No password markers found in ${container_name} logs within ${timeout}s${NC}"
        return 1
    fi
    
    return 0
}

# Function to capture passwords from temporary files
capture_temp_passwords() {
    local temp_files=(
        "/tmp/rustcare-passwords.env"
        "/tmp/stalwart-passwords.env"
        "/tmp/minio-passwords.env"
        "/tmp/redis-passwords.env"
    )
    
    echo -e "${BLUE}🔍 Checking for temporary password files...${NC}"
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            echo -e "${YELLOW}Found password file: $temp_file${NC}"
            
            # Source the temporary file and update .env
            while IFS='=' read -r key value; do
                # Skip comments and empty lines
                if [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]]; then
                    continue
                fi
                
                # Remove any quotes from value
                value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
                
                if [[ -n "$value" ]]; then
                    update_env_password "$key" "$value"
                fi
            done < "$temp_file"
            
            # Clean up temporary file
            rm -f "$temp_file"
            echo -e "${GREEN}✓ Processed and cleaned up $temp_file${NC}"
        fi
    done
}

# Function to start services and capture passwords
start_with_password_capture() {
    local service="$1"
    
    echo -e "${BLUE}🚀 Starting $service with password capture...${NC}"
    
    case "$service" in
        postgres|postgresql)
            echo -e "${YELLOW}Starting PostgreSQL with password generation...${NC}"
            cd "$SCRIPT_DIR"
            
            # Remove any existing container to ensure fresh initialization
            docker-compose stop postgres 2>/dev/null || true
            docker-compose rm -f postgres 2>/dev/null || true
            
            # Start PostgreSQL
            docker-compose up -d postgres
            
            # Wait for container to be ready and capture passwords
            sleep 5
            capture_docker_passwords "rustcare-postgres" 60
            ;;
            
        stalwart|mail)
            echo -e "${YELLOW}Starting Stalwart Mail with password generation...${NC}"
            cd "$SCRIPT_DIR"
            
            # Generate certificates if needed
            if [[ ! -f "certs/cert.pem" ]]; then
                ./certs/generate-certs.sh
            fi
            
            # Process configuration template with current .env values
            ./process-templates.sh
            
            docker-compose stop stalwart-mail 2>/dev/null || true
            docker-compose rm -f stalwart-mail 2>/dev/null || true
            docker-compose up -d stalwart-mail
            
            sleep 5
            capture_docker_passwords "rustcare-stalwart" 30
            ;;
            
        minio|storage)
            echo -e "${YELLOW}Starting MinIO with password generation...${NC}"
            cd "$SCRIPT_DIR"
            
            docker-compose stop minio 2>/dev/null || true
            docker-compose rm -f minio 2>/dev/null || true
            docker-compose up -d minio
            
            sleep 5
            capture_docker_passwords "rustcare-minio" 30
            ;;
            
        redis|cache)
            echo -e "${YELLOW}Starting Redis with password generation...${NC}"
            cd "$SCRIPT_DIR"
            
            docker-compose stop redis 2>/dev/null || true
            docker-compose rm -f redis 2>/dev/null || true
            docker-compose up -d redis
            
            sleep 3
            capture_docker_passwords "rustcare-redis" 30
            ;;
            
        all)
            echo -e "${YELLOW}Starting all services with password capture...${NC}"
            
            # Start services one by one to capture passwords properly
            start_with_password_capture "postgres"
            start_with_password_capture "redis"
            start_with_password_capture "minio"
            start_with_password_capture "stalwart"
            
            # Start remaining services
            cd "$SCRIPT_DIR"
            docker-compose up -d
            ;;
            
        *)
            echo -e "${RED}❌ Unknown service: $service${NC}"
            echo -e "${BLUE}Available services: postgres, stalwart, minio, redis, all${NC}"
            return 1
            ;;
    esac
    
    # Always check for temporary password files
    capture_temp_passwords
}

# Function to extract passwords from running containers
extract_existing_passwords() {
    echo -e "${BLUE}🔍 Extracting passwords from running containers...${NC}"
    
    local containers=(
        "rustcare-postgres:postgres"
        "rustcare-stalwart:stalwart"
        "rustcare-minio:minio"
        "rustcare-redis:redis"
    )
    
    for container_info in "${containers[@]}"; do
        local container_name="${container_info%:*}"
        local service_name="${container_info#*:}"
        
        if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
            echo -e "${YELLOW}Checking ${container_name}...${NC}"
            capture_docker_passwords "$container_name" 10
        fi
    done
    
    capture_temp_passwords
}

# Function to show captured passwords
show_captured_passwords() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}❌ .env file not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📋 Current passwords in .env:${NC}"
    echo ""
    
    local password_keys=(
        "POSTGRES_PASSWORD"
        "RUSTCARE_DB_PASSWORD"
        "STALWART_PASSWORD"
        "MINIO_ROOT_PASSWORD"
        "REDIS_PASSWORD"
        "GRAFANA_PASSWORD"
        "MAIL_ADMIN_PASSWORD"
        "JWT_SECRET"
        "ADMIN_SECRET_KEY"
    )
    
    for key in "${password_keys[@]}"; do
        local value=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || echo "NOT_SET")
        
        if [[ "$value" == "NOT_SET" ]]; then
            echo -e "   ${key}: ${RED}❌ Not set${NC}"
        else
            local masked="${value:0:4}****${value: -4}"
            echo -e "   ${key}: ${GREEN}✓ ${masked}${NC}"
        fi
    done
}

# Usage function
usage() {
    echo -e "${BLUE}🔐 RustCare Password Capture System${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [SERVICE]"
    echo ""
    echo "Commands:"
    echo "  start <service>      Start service and capture generated passwords"
    echo "  extract             Extract passwords from running containers"
    echo "  show                Show current passwords in .env (masked)"
    echo "  monitor <container>  Monitor container logs for password generation"
    echo ""
    echo "Services:"
    echo "  postgres            PostgreSQL database"
    echo "  stalwart            Stalwart mail server"
    echo "  minio               MinIO object storage"
    echo "  redis               Redis cache"
    echo "  all                 All services"
    echo ""
    echo "Examples:"
    echo "  $0 start postgres           # Start PostgreSQL and capture passwords"
    echo "  $0 start all               # Start all services with password capture"
    echo "  $0 extract                 # Extract passwords from running containers"
    echo "  $0 show                    # Show current password status"
    echo ""
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${NC}"
        return 1
    fi
}

# Monitor container logs for password generation
monitor_container_logs() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        echo -e "${RED}❌ Container name required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📡 Monitoring ${container_name} logs for password generation...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    echo ""
    
    docker logs -f "$container_name" 2>&1 | while read -r line; do
        if [[ "$line" =~ _PASSWORD=.* ]]; then
            echo -e "${GREEN}🔑 Password found: ${line}${NC}"
        elif [[ "$line" =~ RUSTCARE_INIT_PASSWORDS ]]; then
            echo -e "${CYAN}📋 Password block: ${line}${NC}"
        else
            echo "$line"
        fi
    done
}

# Main execution
check_dependencies

case "${1:-}" in
    start)
        if [[ -z "$2" ]]; then
            echo -e "${RED}❌ Service name required${NC}"
            usage
            exit 1
        fi
        start_with_password_capture "$2"
        echo ""
        show_captured_passwords
        ;;
    extract)
        extract_existing_passwords
        echo ""
        show_captured_passwords
        ;;
    show)
        show_captured_passwords
        ;;
    monitor)
        if [[ -z "$2" ]]; then
            echo -e "${RED}❌ Container name required${NC}"
            usage
            exit 1
        fi
        monitor_container_logs "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac