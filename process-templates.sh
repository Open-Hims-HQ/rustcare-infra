#!/bin/bash

# Process Stalwart configuration template with environment variables
# This script replaces template variables with actual values from .env

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/stalwart/config.toml.template"
CONFIG_FILE="$SCRIPT_DIR/stalwart/config.toml"
ENV_FILE="$SCRIPT_DIR/.env"

# Source environment variables
if [[ -f "$ENV_FILE" ]]; then
    # Export variables from .env file
    export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)
else
    echo "Warning: .env file not found"
    exit 1
fi

# Set default values if not in .env
STALWART_PASSWORD=${STALWART_PASSWORD:-stalwart_password}
MAIL_SYSTEM_PASSWORD=${MAIL_SYSTEM_PASSWORD:-system_password}

# Process template
if [[ -f "$TEMPLATE_FILE" ]]; then
    echo "Processing Stalwart configuration template..."
    
    # Replace template variables
    envsubst '${STALWART_PASSWORD} ${MAIL_SYSTEM_PASSWORD}' < "$TEMPLATE_FILE" > "$CONFIG_FILE"
    
    echo "✅ Generated $CONFIG_FILE from template"
else
    echo "❌ Template file not found: $TEMPLATE_FILE"
    exit 1
fi