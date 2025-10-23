#!/bin/bash
set -e

# This script runs when PostgreSQL container starts
# It creates the necessary users and databases for RustCare
# It also generates secure passwords and returns them for .env updates

# Function to generate secure passwords
generate_password() {
    local length=${1:-24}
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# Generate passwords
RUSTCARE_PASSWORD=$(generate_password 32)
STALWART_PASSWORD=$(generate_password 32)

echo "Setting up RustCare databases..."
echo ""
echo "🔐 Generated secure passwords:"
echo "RUSTCARE_PASSWORD=${RUSTCARE_PASSWORD}"
echo "STALWART_PASSWORD=${STALWART_PASSWORD}"
echo ""

# Save passwords to a file that can be read by the host
PASSWORD_FILE="/tmp/rustcare-passwords.env"
cat > "$PASSWORD_FILE" << EOF
# Generated passwords from PostgreSQL initialization
# Generated at: $(date)
RUSTCARE_PASSWORD=${RUSTCARE_PASSWORD}
STALWART_PASSWORD=${STALWART_PASSWORD}
EOF

echo "💾 Passwords saved to: $PASSWORD_FILE"
echo ""

# Create rustcare user if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create rustcare user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rustcare') THEN
            CREATE USER rustcare WITH 
                ENCRYPTED PASSWORD '${RUSTCARE_PASSWORD}'
                CREATEDB 
                LOGIN;
        END IF;
    END
    \$\$;

    -- Create stalwart user for mail server
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'stalwart') THEN
            CREATE USER stalwart WITH 
                ENCRYPTED PASSWORD '${STALWART_PASSWORD}'
                CREATEDB 
                LOGIN;
        END IF;
    END
    \$\$;

    -- Grant necessary permissions
    ALTER USER rustcare CREATEDB;
    ALTER USER stalwart CREATEDB;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO rustcare;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO stalwart;
EOSQL

# Create development database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create development database
    SELECT 'CREATE DATABASE rustcare_dev OWNER rustcare ENCODING ''UTF8'' LC_COLLATE=''C'' LC_CTYPE=''C''' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rustcare_dev')\gexec
EOSQL

# Create test database  
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create test database
    SELECT 'CREATE DATABASE rustcare_test OWNER rustcare ENCODING ''UTF8'' LC_COLLATE=''C'' LC_CTYPE=''C''' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rustcare_test')\gexec
EOSQL

# Create stalwart database for mail server
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create stalwart database
    SELECT 'CREATE DATABASE stalwart OWNER stalwart ENCODING ''UTF8'' LC_COLLATE=''C'' LC_CTYPE=''C''' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'stalwart')\gexec
EOSQL

# Enable extensions on development database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "rustcare_dev" <<-EOSQL
    -- Enable required extensions
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
    CREATE EXTENSION IF NOT EXISTS "btree_gin";
    CREATE EXTENSION IF NOT EXISTS "btree_gist";
    CREATE EXTENSION IF NOT EXISTS "citext";
    
    -- Grant usage to rustcare user
    GRANT ALL ON SCHEMA public TO rustcare;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rustcare;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rustcare;
EOSQL

# Enable extensions on test database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "rustcare_test" <<-EOSQL
    -- Enable required extensions
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
    CREATE EXTENSION IF NOT EXISTS "btree_gin";
    CREATE EXTENSION IF NOT EXISTS "btree_gist";
    CREATE EXTENSION IF NOT EXISTS "citext";
    
    -- Grant usage to rustcare user
    GRANT ALL ON SCHEMA public TO rustcare;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rustcare;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rustcare;
EOSQL

# Enable extensions on stalwart database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "stalwart" <<-EOSQL
    -- Enable required extensions for Stalwart
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "citext";
    
    -- Grant usage to stalwart user
    GRANT ALL ON SCHEMA public TO stalwart;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO stalwart;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO stalwart;
EOSQL

# Initialize Stalwart mail server schema if file exists
STALWART_SCHEMA="/docker-entrypoint-initdb.d/../stalwart/sql/init.sql"
if [ -f "$STALWART_SCHEMA" ]; then
    echo "Initializing Stalwart mail server schema..."
    psql -v ON_ERROR_STOP=1 --username "stalwart" --dbname "stalwart" -f "$STALWART_SCHEMA" || echo "Stalwart schema initialization failed, but continuing..."
else
    echo "Stalwart schema file not found at $STALWART_SCHEMA, skipping mail server initialization"
fi

echo ""
echo "✅ RustCare database setup complete!"
echo ""
echo "🔑 IMPORTANT: Update your .env file with these passwords:"
echo "POSTGRES_PASSWORD=\$POSTGRES_PASSWORD"
echo "RUSTCARE_DB_PASSWORD=${RUSTCARE_PASSWORD}"
echo "STALWART_PASSWORD=${STALWART_PASSWORD}"
echo ""
echo "📋 Connection strings:"
echo "postgresql://rustcare:${RUSTCARE_PASSWORD}@localhost:5432/rustcare_dev"
echo "postgresql://stalwart:${STALWART_PASSWORD}@localhost:5432/stalwart"
echo ""

# Also output to Docker logs so it can be captured
echo "RUSTCARE_INIT_PASSWORDS_START"
echo "RUSTCARE_PASSWORD=${RUSTCARE_PASSWORD}"
echo "STALWART_PASSWORD=${STALWART_PASSWORD}"
echo "RUSTCARE_INIT_PASSWORDS_END"