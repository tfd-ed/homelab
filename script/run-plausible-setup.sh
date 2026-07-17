#!/bin/bash
# Run Plausible Analytics setup
# Usage: ./script/run-plausible-setup.sh
#
# Reads credentials from ansible/.env
# Required variables in ansible/.env:
#   POSTGRES_PASSWORD     - existing postgres superuser password
#   PLAUSIBLE_DB_PASSWORD - password for the plausible postgres user
#   PLAUSIBLE_SECRET_KEY  - 64-char hex (generate: openssl rand -hex 64)

set -euo pipefail

# Change to project root
cd "$(dirname "$0")/.."

# Load .env file
if [ ! -f ansible/.env ]; then
    echo "❌ Error: ansible/.env file not found!"
    echo "Please create it from the example:"
    echo "  cp ansible/.env.example ansible/.env"
    echo "  nano ansible/.env  # Fill in your passwords"
    exit 1
fi

echo "Loading environment variables from ansible/.env..."
set -a
source ansible/.env
set +a

# Validate required vars
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is not set in ansible/.env}"
: "${PLAUSIBLE_DB_PASSWORD:?PLAUSIBLE_DB_PASSWORD is not set in ansible/.env}"
: "${PLAUSIBLE_SECRET_KEY:?PLAUSIBLE_SECRET_KEY is not set in ansible/.env (run: openssl rand -hex 64)}"

echo "Running Plausible Analytics setup..."
cd ansible
ansible-playbook playbooks/services/plausible-setup.yml "$@"
