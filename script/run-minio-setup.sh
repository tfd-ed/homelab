#!/bin/bash

# Run MinIO setup playbook
# This script sets up MinIO object storage on the minio-vm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"

cd "$ANSIBLE_DIR"

# Check if inventory.ini exists
if [ ! -f "inventory.ini" ]; then
    echo "Error: inventory.ini not found!"
    echo "Please create inventory.ini from inventory.ini.example"
    exit 1
fi

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "Loading credentials from .env file..."
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
else
    echo "Warning: .env file not found in $ANSIBLE_DIR"
    echo "Please create .env file with MINIO_ROOT_USER and MINIO_ROOT_PASSWORD"
    exit 1
fi

# Verify required variables are set
if [ -z "$MINIO_ROOT_USER" ] || [ -z "$MINIO_ROOT_PASSWORD" ]; then
    echo "Error: MINIO_ROOT_USER and MINIO_ROOT_PASSWORD must be set in .env file"
    exit 1
fi

echo "Setting up MinIO..."
ansible-playbook -i inventory.ini playbooks/services/minio-setup.yml

echo ""
echo "MinIO setup complete!"
echo "You can access the MinIO Console at: http://192.168.100.206:9001"
echo "API Endpoint: http://192.168.100.206:9000"
