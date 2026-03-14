#!/bin/bash
# Cleanup SSH known_hosts after VM recreation
# This removes old SSH host keys for all VMs to prevent host key verification errors

echo "Removing old SSH host keys from known_hosts..."

# List of VM IPs from inventory
VM_IPS=(
  "192.168.100.201"  # k8s-master
  "192.168.100.202"  # k8s-worker-1
  "192.168.100.203"  # k8s-worker-2
  "192.168.100.205"  # database-vm
  "192.168.100.210"  # gateway-vm
  "192.168.100.220"  # monitoring
  "192.168.100.230"  # n8n
  "192.168.100.240"  # ci-cd
)

for ip in "${VM_IPS[@]}"; do
  echo "Removing $ip..."
  ssh-keygen -R "$ip" 2>/dev/null
done

echo "✓ Cleanup complete! You can now SSH to your VMs without host key errors."
