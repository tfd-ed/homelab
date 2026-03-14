#!/bin/bash

# Script to generate SSH keys for VM access
# Usage: ./generate-ssh-keys.sh

set -e

KEYS_DIR="./ssh-keys"
KEY_NAME="vm-key"
KEY_TYPE="rsa"
KEY_BITS="4096"

echo "=========================================="
echo "SSH Key Generator for VMs"
echo "=========================================="
echo ""

# Create keys directory if it doesn't exist
if [ ! -d "$KEYS_DIR" ]; then
    mkdir -p "$KEYS_DIR"
    echo "✓ Created directory: $KEYS_DIR"
else
    echo "✓ Directory already exists: $KEYS_DIR"
fi

# Check if key already exists
if [ -f "$KEYS_DIR/$KEY_NAME" ]; then
    echo ""
    echo "⚠ Warning: Key pair already exists at $KEYS_DIR/$KEY_NAME"
    read -p "Do you want to overwrite it? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Aborted. Existing keys preserved."
        exit 0
    fi
    echo "Overwriting existing keys..."
fi

# Generate SSH key pair
echo ""
echo "Generating $KEY_TYPE SSH key pair ($KEY_BITS bits)..."
ssh-keygen -t $KEY_TYPE -b $KEY_BITS -f "$KEYS_DIR/$KEY_NAME" -N "" -C "vm-access-key"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ SSH Key Generation Complete!"
    echo "=========================================="
    echo ""
    echo "Private key: $KEYS_DIR/$KEY_NAME"
    echo "Public key:  $KEYS_DIR/$KEY_NAME.pub"
    echo ""
    
    # Set proper permissions
    chmod 600 "$KEYS_DIR/$KEY_NAME"
    chmod 644 "$KEYS_DIR/$KEY_NAME.pub"
    echo "✓ Permissions set correctly"
    
    # Display public key
    echo ""
    echo "=========================================="
    echo "Your Public Key:"
    echo "=========================================="
    cat "$KEYS_DIR/$KEY_NAME.pub"
    echo ""
    
    # Instructions
    echo "=========================================="
    echo "Next Steps:"
    echo "=========================================="
    echo ""
    echo "1. Copy the public key above"
    echo ""
    echo "2. Edit vm.tf and replace the placeholder SSH key in the cloud-init user_data:"
    echo "   ssh_authorized_keys:"
    echo "     - <paste_your_public_key_here>"
    echo ""
    echo "3. Or run the update script:"
    echo "   ./update-vm-ssh-key.sh"
    echo ""
    echo "4. Deploy or redeploy your VMs:"
    echo "   terraform apply"
    echo ""
    echo "5. Connect to VMs using the private key:"
    echo "   ssh -i $KEYS_DIR/$KEY_NAME ubuntu@<vm-ip>"
    echo ""
    
else
    echo "✗ Error: Failed to generate SSH keys"
    exit 1
fi
