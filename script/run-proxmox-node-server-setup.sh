#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Proxmox Temperature Server Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check we are running from the project root
if [ ! -f "ansible/playbooks/infrastructure/proxmox-node-server-setup.yml" ]; then
    echo -e "${RED}ERROR: Please run this script from the project root directory${NC}"
    exit 1
fi

# Optional: --tunnel flag to target via Cloudflare tunnel instead of direct IP
TARGET_HOST="proxmox"
EXTRA_ARGS=""

for arg in "$@"; do
    case $arg in
        --tunnel)
            TARGET_HOST="tunnel"
            echo -e "${YELLOW}Using Cloudflare tunnel to reach Proxmox host${NC}"
            ;;
        --tags=*)
            EXTRA_ARGS="$EXTRA_ARGS --tags ${arg#--tags=}"
            ;;
        --check)
            EXTRA_ARGS="$EXTRA_ARGS --check"
            echo -e "${YELLOW}Dry-run mode (--check)${NC}"
            ;;
    esac
done

echo -e "${YELLOW}Target host group: ${TARGET_HOST}${NC}"
echo ""

# Run the playbook
ansible-playbook \
    -i ansible/inventory.ini \
    ansible/playbooks/infrastructure/proxmox-node-server-setup.yml \
    --limit "$TARGET_HOST" \
    $EXTRA_ARGS \
    "$@"

STATUS=$?
echo ""
if [ $STATUS -eq 0 ]; then
    echo -e "${GREEN}Setup complete!${NC}"
    echo -e "${GREEN}Endpoints available on Proxmox host:${NC}"
    echo -e "  GET /health            – liveness check"
    echo -e "  GET /temperature       – all sensor readings"
    echo -e "  GET /temperature/cpu   – CPU/core temperatures only"
    echo -e "  GET /temperature/raw   – raw sensors -j output"
    echo ""
    echo -e "${YELLOW}Default port: 3000  (override with PORT env var in the service unit)${NC}"
else
    echo -e "${RED}Setup failed (exit code: $STATUS)${NC}"
    exit $STATUS
fi
