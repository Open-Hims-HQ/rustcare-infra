#!/bin/bash

# Generate self-signed certificates for Stalwart Mail Server
# For development use only - use proper certificates in production

set -e

CERT_DIR="/Users/apple/Projects/rustcare-infra/certs"
DOMAIN="mail.rustcare.local"

echo "Generating self-signed certificates for $DOMAIN..."

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Generate private key
openssl genrsa -out "$CERT_DIR/key.pem" 2048

# Generate certificate signing request
openssl req -new -key "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.csr" -subj "/C=US/ST=CA/L=San Francisco/O=RustCare/OU=Mail/CN=$DOMAIN"

# Generate self-signed certificate
openssl x509 -req -in "$CERT_DIR/cert.csr" -signkey "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" -days 365

# Generate DKIM key
openssl genrsa -out "$CERT_DIR/dkim.key" 1024

# Extract DKIM public key
openssl rsa -in "$CERT_DIR/dkim.key" -pubout -out "$CERT_DIR/dkim.pub"

# Set proper permissions
chmod 600 "$CERT_DIR/key.pem" "$CERT_DIR/dkim.key"
chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/dkim.pub"

# Clean up CSR
rm "$CERT_DIR/cert.csr"

echo "Certificates generated successfully!"
echo ""
echo "Files created:"
echo "  $CERT_DIR/cert.pem  - TLS certificate"
echo "  $CERT_DIR/key.pem   - TLS private key"
echo "  $CERT_DIR/dkim.key  - DKIM private key"
echo "  $CERT_DIR/dkim.pub  - DKIM public key"
echo ""
echo "Add this DKIM DNS record to your domain:"
echo "default._domainkey.$DOMAIN IN TXT \"v=DKIM1; k=rsa; p=$(grep -v '^-' $CERT_DIR/dkim.pub | tr -d '\n')\""