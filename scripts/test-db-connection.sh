#!/bin/bash
# Test database connection using environment variables

set -e

# Load environment variables from .env if it exists
if [ -f .env ]; then
    # Source .env file properly (handles values with spaces/special chars)
    set -a
    source .env
    set +a
fi

# Default values from docker-compose.yml
POSTGRES_USER=${POSTGRES_USER:-rustcare}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}
POSTGRES_DB=${POSTGRES_DB:-rustcare}
POSTGRES_HOST=${POSTGRES_HOST:-localhost}
POSTGRES_PORT=${POSTGRES_PORT:-5432}

# Check if password needs to be updated from docker-compose
# If postgres container exists, get the actual password from container env
if docker ps -a | grep -q rustcare-postgres; then
    CONTAINER_PASSWORD=$(docker inspect rustcare-postgres 2>/dev/null | grep -A 10 "Env" | grep POSTGRES_PASSWORD | sed 's/.*POSTGRES_PASSWORD=\([^,]*\).*/\1/' | tr -d '"' | head -1)
    if [ -n "$CONTAINER_PASSWORD" ] && [ "$CONTAINER_PASSWORD" != "changeme" ]; then
        echo "⚠ Found updated password in container, using it..."
        POSTGRES_PASSWORD="$CONTAINER_PASSWORD"
    fi
fi

# Construct DATABASE_URL
DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

echo "Testing database connection..."
echo "Host: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo "Database: ${POSTGRES_DB}"
echo "User: ${POSTGRES_USER}"
echo ""

# Check if postgres container is running
if docker ps | grep -q rustcare-postgres; then
    echo "✓ PostgreSQL container is running"
    
    # Test connection via docker exec
    echo "Testing connection via docker exec..."
    if docker exec rustcare-postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT version();" > /dev/null 2>&1; then
        echo "✓ Database connection successful via docker exec"
        docker exec rustcare-postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT version();" | head -3
    else
        echo "✗ Database connection failed via docker exec"
        exit 1
    fi
else
    echo "⚠ PostgreSQL container is not running"
    echo "Starting postgres service..."
    docker-compose up -d postgres
    
    echo "Waiting for postgres to be ready..."
    sleep 5
    
    # Wait for postgres to be ready
    for i in {1..30}; do
        if docker exec rustcare-postgres pg_isready -U "${POSTGRES_USER}" > /dev/null 2>&1; then
            echo "✓ PostgreSQL is ready"
            break
        fi
        echo "Waiting for postgres... ($i/30)"
        sleep 1
    done
fi

# Test connection via psql if available
if command -v psql &> /dev/null; then
    echo ""
    echo "Testing connection via psql client..."
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    if psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT version();" > /dev/null 2>&1; then
        echo "✓ Database connection successful via psql client"
        psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT version();" | head -3
    else
        echo "⚠ Could not connect via psql client (may need to install postgresql-client)"
    fi
    unset PGPASSWORD
fi

# Test with sqlx if available
if command -v sqlx &> /dev/null; then
    echo ""
    echo "Testing connection via sqlx..."
    if sqlx database create --database-url "${DATABASE_URL}" 2>&1 | grep -q "already exists\|created"; then
        echo "✓ Database connection successful via sqlx"
    else
        echo "⚠ Could not verify connection via sqlx"
    fi
fi

echo ""
echo "DATABASE_URL for use in builds:"
echo "${DATABASE_URL}"
echo ""
echo "To use this in Docker build, run:"
echo "docker build --build-arg DATABASE_URL='${DATABASE_URL}' ..."

