#!/bin/bash

# Migrate MinIO data from database VM to dedicated MinIO VM
# This script uses the MinIO client to mirror all buckets

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

echo ""
echo "========================================="
echo "MinIO Data Migration"
echo "========================================="
echo "Source: http://192.168.100.205:9000 (database-vm)"
echo "Target: http://192.168.100.206:9000 (minio-vm)"
echo "========================================="
echo ""
echo "This will migrate all buckets and objects from the old MinIO"
echo "instance to the new dedicated MinIO VM."
echo ""

read -p "Do you want to proceed? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "Starting migration..."
ansible-playbook -i inventory.ini playbooks/services/minio-migrate.yml

echo ""
echo "Migration process complete!"
echo ""
echo "Next steps:"
echo "1. Verify all data migrated correctly"
echo "2. Update application configurations to point to new MinIO (192.168.100.206)"
echo "3. Consider stopping the old MinIO on database-vm"
