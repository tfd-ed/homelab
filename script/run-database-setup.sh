#!/bin/bash
# Run Ansible playbook with environment variables from .env file

# Change to project root directory
cd "$(dirname "$0")/.."

# Check if .env file exists
if [ ! -f ansible/.env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create it from .env.example:"
    echo "  cp ansible/.env.example ansible/.env"
    echo "  nano ansible/.env  # Edit with your passwords"
    exit 1
fi

# Load environment variables
echo "Loading environment variables from .env..."
set -a
source ansible/.env
set +a

# Run the playbook
echo "Running database-setup.yml..."
cd ansible
ansible-playbook playbooks/services/database-setup.yml "$@"
