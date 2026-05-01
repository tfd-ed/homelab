#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"

cd "$ANSIBLE_DIR"

echo "Setting up AI VM with Ollama..."
ansible-playbook playbooks/services/ai-vm-setup.yml -i inventory.ini "$@"
echo "Done."
