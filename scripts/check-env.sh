#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Checking RustCare Environment...${NC}"

# Check for required tools
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed.${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 is installed.${NC}"
        return 0
    fi
}

MISSING_TOOLS=0

check_tool "docker" || MISSING_TOOLS=1
check_tool "cargo" || MISSING_TOOLS=1
check_tool "node" || MISSING_TOOLS=1
check_tool "npm" || MISSING_TOOLS=1

if [ $MISSING_TOOLS -eq 1 ]; then
    echo -e "${RED}Please install missing tools before proceeding.${NC}"
    exit 1
fi

# Check for .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found.${NC}"
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo -e "${GREEN}✅ .env created. Please update it with your secrets.${NC}"
else
    echo -e "${GREEN}✅ .env file exists.${NC}"
fi

# Check for directory structure
if [ ! -d "../rustcare-engine" ]; then
    echo -e "${RED}❌ rustcare-engine directory not found at ../rustcare-engine${NC}"
    exit 1
fi

if [ ! -d "../rustcare-ui" ]; then
    echo -e "${RED}❌ rustcare-ui directory not found at ../rustcare-ui${NC}"
    exit 1
fi

echo -e "${GREEN}Environment check passed!${NC}"
exit 0
