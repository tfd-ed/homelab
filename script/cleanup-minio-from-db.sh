#!/bin/bash

# Cleanup MinIO from Database VM
# This script removes the old MinIO container and optionally the data

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

echo ""
echo "========================================="
echo "MinIO Cleanup on Database VM"
echo "========================================="
echo ""
echo "This script will clean up the old MinIO installation"
echo "from the database VM (192.168.100.205) to free resources."
echo ""
echo "What will be done:"
echo "  1. Stop the MinIO container"
echo "  2. Remove the MinIO container"
echo "  3. Optionally backup the data"
echo "  4. Optionally remove the data directory"
echo "  5. Free up ports 9000 and 9001"
echo ""
echo "⚠️  WARNING: Make sure you have successfully migrated"
echo "   data to the new MinIO VM (192.168.100.206) first!"
echo ""

read -p "Have you verified the migration is successful? (yes/no): " verified
if [ "$verified" != "yes" ]; then
    echo ""
    echo "Please verify the migration first:"
    echo "  1. Check buckets on new MinIO: mc ls target-minio"
    echo "  2. Test accessing files from your applications"
    echo "  3. Run: mc diff source-minio/BUCKET target-minio/BUCKET"
    echo ""
    exit 0
fi

echo ""
read -p "Do you want to proceed with cleanup? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
ansible-playbook -i inventory.ini playbooks/services/minio-cleanup.yml

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Verify database VM containers: ssh ubuntu@192.168.100.205 'docker ps'"
echo "  2. Check disk usage: ssh ubuntu@192.168.100.205 'df -h'"
echo "  3. Ensure applications are using new MinIO (192.168.100.206:9000)"
echo ""
