#!/bin/bash

# Password Generation Utility for RustCare Infrastructure
# Generates secure random passwords and updates configuration files

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

# Generate a secure random password
generate_password() {
    local length=${1:-24}
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# Generate a bcrypt hash for a password
generate_bcrypt_hash() {
    local password="$1"
    python3 -c "
import bcrypt
password = b'$password'
hashed = bcrypt.hashpw(password, bcrypt.gensalt(rounds=12))
print(hashed.decode('utf-8'))
" 2>/dev/null || {
        echo -e "${YELLOW}Warning: bcrypt not available, using plain password${NC}" >&2
        echo "$password"
    }
}

# Update .env file with new password
update_env_password() {
    local key="$1"
    local value="$2"
    local env_file="$SCRIPT_DIR/.env"
    
    if [[ -f "$env_file" ]]; then
        if grep -q "^${key}=" "$env_file"; then
            # Update existing key
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
            else
                sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
            fi
        else
            # Add new key
            echo "${key}=${value}" >> "$env_file"
        fi
    else
        echo -e "${YELLOW}Warning: .env file not found${NC}" >&2
    fi
}

# Update Stalwart SQL init script with new passwords
update_stalwart_passwords() {
    local admin_password="$1"
    local system_password="$2"
    local noreply_password="$3"
    local admin_hash="$4"
    local system_hash="$5"
    local noreply_hash="$6"
    
    local sql_file="$SCRIPT_DIR/stalwart/sql/init.sql"
    
    if [[ -f "$sql_file" ]]; then
        # Create backup
        cp "$sql_file" "$sql_file.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update password hashes in SQL file
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|\\\$2b\\\$12\\\$[^']*|${admin_hash}|g" "$sql_file"
        else
            sed -i "s|\\\$2b\\\$12\\\$[^']*|${admin_hash}|g" "$sql_file"
        fi
        
        echo -e "${GREEN}✓ Updated Stalwart password hashes${NC}"
    fi
}

# Generate all passwords and display them
generate_all_passwords() {
    echo -e "${BLUE}🔐 Generating secure random passwords...${NC}"
    echo ""
    
    # Generate passwords
    local postgres_password=$(generate_password 32)
    local stalwart_db_password=$(generate_password 32)
    local minio_password=$(generate_password 24)
    local grafana_password=$(generate_password 20)
    local admin_password=$(generate_password 16)
    local system_password=$(generate_password 24)
    local noreply_password=$(generate_password 24)
    local jwt_secret=$(generate_password 64)
    local admin_secret=$(generate_password 64)
    
    # Generate bcrypt hashes for mail accounts
    local admin_hash=$(generate_bcrypt_hash "$admin_password")
    local system_hash=$(generate_bcrypt_hash "$system_password")
    local noreply_hash=$(generate_bcrypt_hash "$noreply_password")
    
    # Update .env file
    echo -e "${YELLOW}Updating .env file...${NC}"
    update_env_password "POSTGRES_PASSWORD" "$postgres_password"
    update_env_password "STALWART_PASSWORD" "$stalwart_db_password"
    update_env_password "MINIO_ROOT_PASSWORD" "$minio_password"
    update_env_password "GRAFANA_PASSWORD" "$grafana_password"
    update_env_password "MAIL_ADMIN_PASSWORD" "$admin_password"
    update_env_password "JWT_SECRET" "$jwt_secret"
    update_env_password "ADMIN_SECRET_KEY" "$admin_secret"
    
    # Update Stalwart passwords
    echo -e "${YELLOW}Updating Stalwart mail passwords...${NC}"
    update_stalwart_passwords "$admin_password" "$system_password" "$noreply_password" "$admin_hash" "$system_hash" "$noreply_hash"
    
    # Display results
    echo ""
    echo -e "${GREEN}🎉 Passwords generated successfully!${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                      SECURE PASSWORDS                         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📊 Database Passwords:${NC}"
    echo -e "   PostgreSQL:        ${YELLOW}${postgres_password}${NC}"
    echo -e "   Stalwart DB:       ${YELLOW}${stalwart_db_password}${NC}"
    echo ""
    echo -e "${BLUE}☁️  Service Passwords:${NC}"
    echo -e "   MinIO:             ${YELLOW}${minio_password}${NC}"
    echo -e "   Grafana:           ${YELLOW}${grafana_password}${NC}"
    echo ""
    echo -e "${BLUE}📧 Mail Account Passwords:${NC}"
    echo -e "   admin@rustcare.local:    ${YELLOW}${admin_password}${NC}"
    echo -e "   system@rustcare.local:   ${YELLOW}${system_password}${NC}"
    echo -e "   noreply@rustcare.local:  ${YELLOW}${noreply_password}${NC}"
    echo ""
    echo -e "${BLUE}🔐 Security Keys:${NC}"
    echo -e "   JWT Secret:        ${YELLOW}${jwt_secret:0:20}...${NC}"
    echo -e "   Admin Secret:      ${YELLOW}${admin_secret:0:20}...${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}✅ All passwords saved to .env file${NC}"
    echo -e "${GREEN}✅ Mail account hashes updated in Stalwart configuration${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT SECURITY NOTES:${NC}"
    echo -e "   • Save these passwords in a secure password manager"
    echo -e "   • The .env file contains sensitive credentials"
    echo -e "   • Rotate passwords regularly in production"
    echo -e "   • Use different passwords for different environments"
    echo ""
    
    # Save to secure file for later reference
    local password_file="$SCRIPT_DIR/.passwords.$(date +%Y%m%d_%H%M%S).txt"
    cat > "$password_file" << EOF
# RustCare Infrastructure Passwords
# Generated: $(date)
# Environment: ${ENVIRONMENT:-development}

# Database Passwords
POSTGRES_PASSWORD=${postgres_password}
STALWART_PASSWORD=${stalwart_db_password}

# Service Passwords  
MINIO_ROOT_PASSWORD=${minio_password}
GRAFANA_PASSWORD=${grafana_password}

# Mail Account Passwords
MAIL_ADMIN_PASSWORD=${admin_password}
MAIL_SYSTEM_PASSWORD=${system_password}
MAIL_NOREPLY_PASSWORD=${noreply_password}

# Security Keys
JWT_SECRET=${jwt_secret}
ADMIN_SECRET_KEY=${admin_secret}

# Login Information
# PostgreSQL: postgresql://rustcare:${postgres_password}@localhost:5432/rustcare_dev
# PostgreSQL (Stalwart): postgresql://stalwart:${stalwart_db_password}@localhost:5432/stalwart
# MinIO Console: http://localhost:9001 (rustcare/${minio_password})
# Grafana: http://localhost:3001 (admin/${grafana_password})
# Mail Admin: http://localhost:8080 (admin@rustcare.local/${admin_password})
EOF
    
    chmod 600 "$password_file"
    echo -e "${BLUE}📄 Passwords also saved to: ${password_file}${NC}"
    echo -e "${YELLOW}   (This file has restricted permissions - 600)${NC}"
}

# Reset specific service password
reset_service_password() {
    local service="$1"
    
    case "$service" in
        postgres|postgresql)
            local new_password=$(generate_password 32)
            update_env_password "POSTGRES_PASSWORD" "$new_password"
            echo -e "${GREEN}✓ PostgreSQL password reset${NC}"
            echo -e "New password: ${YELLOW}${new_password}${NC}"
            echo -e "${YELLOW}Restart PostgreSQL: docker-compose restart postgres${NC}"
            ;;
        stalwart-db)
            local new_password=$(generate_password 32)
            update_env_password "STALWART_PASSWORD" "$new_password"
            echo -e "${GREEN}✓ Stalwart database password reset${NC}"
            echo -e "New password: ${YELLOW}${new_password}${NC}"
            echo -e "${YELLOW}Restart services: docker-compose restart postgres stalwart-mail${NC}"
            ;;
        minio)
            local new_password=$(generate_password 24)
            update_env_password "MINIO_ROOT_PASSWORD" "$new_password"
            echo -e "${GREEN}✓ MinIO password reset${NC}"
            echo -e "New password: ${YELLOW}${new_password}${NC}"
            echo -e "${YELLOW}Restart MinIO: docker-compose restart minio${NC}"
            ;;
        grafana)
            local new_password=$(generate_password 20)
            update_env_password "GRAFANA_PASSWORD" "$new_password"
            echo -e "${GREEN}✓ Grafana password reset${NC}"
            echo -e "New password: ${YELLOW}${new_password}${NC}"
            echo -e "${YELLOW}Restart Grafana: docker-compose restart grafana${NC}"
            ;;
        mail-admin)
            local new_password=$(generate_password 16)
            local new_hash=$(generate_bcrypt_hash "$new_password")
            update_env_password "MAIL_ADMIN_PASSWORD" "$new_password"
            echo -e "${GREEN}✓ Mail admin password reset${NC}"
            echo -e "New password: ${YELLOW}${new_password}${NC}"
            echo -e "New hash: ${YELLOW}${new_hash}${NC}"
            echo -e "${YELLOW}Update Stalwart SQL and restart: docker-compose restart stalwart-mail${NC}"
            ;;
        jwt)
            local new_secret=$(generate_password 64)
            update_env_password "JWT_SECRET" "$new_secret"
            echo -e "${GREEN}✓ JWT secret reset${NC}"
            echo -e "New secret: ${YELLOW}${new_secret:0:20}...${NC}"
            ;;
        *)
            echo -e "${RED}❌ Unknown service: $service${NC}"
            echo -e "${BLUE}Available services:${NC}"
            echo "  • postgres       - PostgreSQL database"
            echo "  • stalwart-db    - Stalwart mail database"
            echo "  • minio          - MinIO object storage"
            echo "  • grafana        - Grafana monitoring"
            echo "  • mail-admin     - Mail admin account"
            echo "  • jwt            - JWT signing secret"
            return 1
            ;;
    esac
}

# Show current passwords (masked)
show_passwords() {
    local env_file="$SCRIPT_DIR/.env"
    
    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}❌ .env file not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Current password status:${NC}"
    echo ""
    
    local passwords=(
        "POSTGRES_PASSWORD:PostgreSQL"
        "STALWART_PASSWORD:Stalwart DB"
        "MINIO_ROOT_PASSWORD:MinIO"
        "GRAFANA_PASSWORD:Grafana"
        "MAIL_ADMIN_PASSWORD:Mail Admin"
        "JWT_SECRET:JWT Secret"
        "ADMIN_SECRET_KEY:Admin Secret"
    )
    
    for password_info in "${passwords[@]}"; do
        local key="${password_info%:*}"
        local name="${password_info#*:}"
        local value=$(grep "^${key}=" "$env_file" 2>/dev/null | cut -d'=' -f2- || echo "NOT_SET")
        
        if [[ "$value" == "NOT_SET" ]]; then
            echo -e "   ${name}: ${RED}❌ Not set${NC}"
        else
            local masked="${value:0:4}$( printf '*%.0s' {1..8} )${value: -4}"
            echo -e "   ${name}: ${GREEN}✓ ${masked}${NC}"
        fi
    done
}

# Usage information
usage() {
    echo -e "${BLUE}🔐 RustCare Password Management${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  generate          Generate all passwords and update configuration"
    echo "  reset <service>   Reset password for specific service"
    echo "  show             Show current password status (masked)"
    echo "  backup           Create backup of current passwords"
    echo ""
    echo "Services for reset:"
    echo "  postgres         PostgreSQL database password"
    echo "  stalwart-db      Stalwart mail database password"
    echo "  minio            MinIO storage password"
    echo "  grafana          Grafana dashboard password"
    echo "  mail-admin       Mail admin account password"
    echo "  jwt              JWT signing secret"
    echo ""
    echo "Examples:"
    echo "  $0 generate                    # Generate all new passwords"
    echo "  $0 reset postgres             # Reset only PostgreSQL password"
    echo "  $0 show                       # Show current password status"
    echo ""
}

# Backup current passwords
backup_passwords() {
    local env_file="$SCRIPT_DIR/.env"
    
    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}❌ .env file not found${NC}"
        return 1
    fi
    
    local backup_file="$SCRIPT_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$env_file" "$backup_file"
    chmod 600 "$backup_file"
    
    echo -e "${GREEN}✓ Passwords backed up to: ${backup_file}${NC}"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}Warning: python3 not found, bcrypt hashing will use plain passwords${NC}"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${NC}"
        echo -e "${BLUE}Install with: brew install ${missing_deps[*]}${NC}"
        return 1
    fi
}

# Main command handling
check_dependencies

case "${1:-}" in
    generate)
        generate_all_passwords
        ;;
    reset)
        if [[ -z "$2" ]]; then
            echo -e "${RED}❌ Service name required${NC}"
            echo "Usage: $0 reset <service>"
            exit 1
        fi
        reset_service_password "$2"
        ;;
    show)
        show_passwords
        ;;
    backup)
        backup_passwords
        ;;
    *)
        usage
        exit 1
        ;;
esac