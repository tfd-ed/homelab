#!/bin/bash

# Alternative MinIO migration using rsync (direct file copy)
# This script stops both MinIO instances, syncs data, and restarts them

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"

SOURCE_VM="ubuntu@192.168.100.205"
TARGET_VM="ubuntu@192.168.100.206"
SSH_KEY="$SCRIPT_DIR/../ssh-keys/vm-key"

SOURCE_DATA_DIR="/opt/databases/minio/data"
TARGET_DATA_DIR="/opt/minio/data"

echo ""
echo "========================================="
echo "MinIO Data Migration (rsync method)"
echo "========================================="
echo "Source: $SOURCE_VM:$SOURCE_DATA_DIR"
echo "Target: $TARGET_VM:$TARGET_DATA_DIR"
echo "========================================="
echo ""
echo "This method will:"
echo "1. Stop MinIO on both VMs"
echo "2. Sync data using rsync"
echo "3. Restart MinIO on both VMs"
echo ""
echo "WARNING: This will cause brief downtime!"
echo ""

read -p "Do you want to proceed? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "Step 1: Stopping MinIO containers..."
echo "  - Stopping on source VM (database-vm)..."
ssh -i "$SSH_KEY" "$SOURCE_VM" "sudo docker stop minio" || echo "  MinIO already stopped on source"

echo "  - Stopping on target VM (minio-vm)..."
ssh -i "$SSH_KEY" "$TARGET_VM" "sudo docker stop minio" || echo "  MinIO already stopped on target"

echo ""
echo "Step 2: Syncing data from source to target..."
echo "  This may take a while depending on data size..."

# Create target directory if it doesn't exist
ssh -i "$SSH_KEY" "$TARGET_VM" "sudo mkdir -p $TARGET_DATA_DIR"

# Rsync through local machine (pull then push)
# This is necessary because direct SSH between VMs may not be configured
TEMP_DIR=$(mktemp -d)
echo "  - Pulling data from source VM to local temp..."
rsync -avz --progress -e "ssh -i $SSH_KEY" "$SOURCE_VM:$SOURCE_DATA_DIR/" "$TEMP_DIR/"

echo "  - Pushing data from local temp to target VM..."
rsync -avz --progress -e "ssh -i $SSH_KEY" "$TEMP_DIR/" "$TARGET_VM:$TARGET_DATA_DIR/"

echo "  - Cleaning up temp directory..."
rm -rf "$TEMP_DIR"

# Set proper ownership on target
echo "  - Setting proper ownership..."
ssh -i "$SSH_KEY" "$TARGET_VM" "sudo chown -R root:root $TARGET_DATA_DIR"

echo ""
echo "Step 3: Starting MinIO containers..."
echo "  - Starting on target VM (minio-vm)..."
ssh -i "$SSH_KEY" "$TARGET_VM" "sudo docker start minio"

echo "  - Starting on source VM (database-vm)..."
ssh -i "$SSH_KEY" "$SOURCE_VM" "sudo docker start minio"

echo ""
echo "Step 4: Waiting for MinIO to be ready..."
sleep 5

echo ""
echo "========================================="
echo "Migration Complete!"
echo "========================================="
echo ""
echo "Verification commands:"
echo "  # List buckets on source:"
echo "  ssh -i $SSH_KEY $SOURCE_VM 'sudo docker exec minio mc ls local'"
echo ""
echo "  # List buckets on target:"
echo "  ssh -i $SSH_KEY $TARGET_VM 'sudo docker exec minio mc ls local'"
echo ""
echo "Next steps:"
echo "1. Verify data integrity by checking a few files"
echo "2. Update application configs to point to new MinIO (192.168.100.206)"
echo "3. Once verified, you can stop old MinIO on database-vm"
