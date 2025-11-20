# Makefile for RustCare Infrastructure
# Single Point of Execution for Build, Deploy, and Management

.PHONY: help setup check build deploy dev clean logs status stop restart

# Default target
help:
	@echo "RustCare Infrastructure - Management Commands"
	@echo "============================================="
	@echo "  make setup    - Setup local environment (check tools, init .env)"
	@echo "  make check    - Validate environment requirements"
	@echo "  make build    - Build Docker images"
	@echo "  make dev      - Start development stack (detached)"
	@echo "  make deploy   - Deploy to production (alias for start)"
	@echo "  make stop     - Stop all services"
	@echo "  make restart  - Restart all services"
	@echo "  make status   - Check health of services"
	@echo "  make logs     - Follow service logs"
	@echo "  make clean    - Stop services and remove volumes (CAUTION)"

# Setup and Validation
setup:
	@./scripts/setup-dev.sh

check:
	@./scripts/check-env.sh

# Core Operations
build: check
	@echo "Loading environment variables from .env (if exists)..."
	@if [ -f .env ]; then \
		set -a; \
		. .env; \
		set +a; \
	fi
	@echo "Ensuring postgres is running for compile-time query checking..."
	@docker-compose up -d postgres || true
	@echo "Waiting for postgres to be ready..."
	@timeout=30; while [ $$timeout -gt 0 ]; do \
		if docker exec rustcare-postgres pg_isready -U $${POSTGRES_USER:-rustcare} > /dev/null 2>&1; then \
			echo "✓ PostgreSQL is ready"; \
			break; \
		fi; \
		sleep 1; \
		timeout=$$((timeout-1)); \
	done
	@echo "Running database migrations (if needed)..."
	@if [ -d "../rustcare-engine/migrations" ]; then \
		docker exec rustcare-postgres psql -U $${POSTGRES_USER:-rustcare} -d $${POSTGRES_DB:-rustcare} -c "SELECT 1" > /dev/null 2>&1 || \
		docker exec -i rustcare-postgres psql -U $${POSTGRES_USER:-rustcare} -d $${POSTGRES_DB:-rustcare} < ../rustcare-engine/migrations/*.sql 2>/dev/null || true; \
	fi
	@echo "Getting database connection info from environment..."
	@CONTAINER_PASSWORD="$${POSTGRES_PASSWORD:-changeme}"; \
	if docker ps -a | grep -q rustcare-postgres; then \
		CONTAINER_PASSWORD=$$(docker inspect rustcare-postgres 2>/dev/null | grep -o 'POSTGRES_PASSWORD=[^,}]*' | cut -d= -f2 | tr -d '"' | tr -d "'" | head -1); \
		if [ -z "$$CONTAINER_PASSWORD" ]; then \
			CONTAINER_PASSWORD="$${POSTGRES_PASSWORD:-changeme}"; \
		fi; \
	fi; \
	if [ -z "$$DATABASE_URL" ]; then \
		BUILD_DATABASE_URL="postgresql://$${POSTGRES_USER:-rustcare}:$$CONTAINER_PASSWORD@host.docker.internal:5432/$${POSTGRES_DB:-rustcare}"; \
		echo "✓ Constructed DATABASE_URL: $${BUILD_DATABASE_URL%%@*}"; \
	else \
		BUILD_DATABASE_URL="$$DATABASE_URL"; \
		echo "✓ Using DATABASE_URL from environment: $${BUILD_DATABASE_URL%%@*}"; \
	fi; \
	echo "Building with DATABASE_URL..."; \
	DATABASE_URL="$$BUILD_DATABASE_URL" \
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build

dev: check
	docker-compose up -d
	@echo "RustCare stack is running!"
	@echo "UI: http://localhost:3000"
	@echo "API: http://localhost:8080"

deploy: build
	docker-compose up -d
	@echo "Deployed successfully."

stop:
	docker-compose down

restart: stop dev

# Monitoring
status:
	docker-compose ps
	@echo ""
	@echo "Health Checks:"
	@docker-compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Health}}"

logs:
	docker-compose logs -f

# Cleanup
clean:
	@echo "Stopping services and removing volumes..."
	docker-compose down -v
	@echo "Clean complete."


