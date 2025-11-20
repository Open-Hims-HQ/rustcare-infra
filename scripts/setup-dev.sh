#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Setting up RustCare Development Environment...${NC}"

# Run environment check
./scripts/check-env.sh

# Generate secrets if they are default
if grep -q "change_me_in_production" .env; then
    echo "Generating new secrets..."
    # Simple random string generation for dev
    JWT_SECRET=$(openssl rand -hex 32)
    sed -i '' "s/change_me_in_production/$JWT_SECRET/" .env
    echo -e "${GREEN}✅ Secrets updated in .env${NC}"
fi

echo -e "${GREEN}Setup complete! Run 'make dev' to start the stack.${NC}"
