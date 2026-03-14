#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}n8n Workflow Automation Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

N8N_VM="192.168.100.230"
DB_VM="192.168.100.205"

# Check if VMs are reachable
echo -e "${YELLOW}Checking VM connectivity...${NC}"
if ! ssh -o ConnectTimeout=5 -i ssh-keys/vm-key ubuntu@${N8N_VM} "echo 'Connected'" &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to n8n VM at ${N8N_VM}${NC}"
    echo "Please ensure the n8n VM is running and SSH is configured"
    exit 1
fi
echo -e "${GREEN}✓ n8n VM is reachable${NC}"

if ! ssh -o ConnectTimeout=5 -i ssh-keys/vm-key ubuntu@${DB_VM} "echo 'Connected'" &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to database VM at ${DB_VM}${NC}"
    echo "Please ensure the database VM is running"
    exit 1
fi
echo -e "${GREEN}✓ Database VM is reachable${NC}"
echo ""

# Check if Docker is installed on n8n VM
echo -e "${YELLOW}Checking Docker installation on n8n VM...${NC}"
if ! ssh -i ssh-keys/vm-key ubuntu@${N8N_VM} "which docker" &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker is not installed on n8n VM${NC}"
    echo "Installing Docker first..."
    cd ansible
    ansible-playbook playbooks/infrastructure/docker-setup.yml -l n8n
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Docker${NC}"
        exit 1
    fi
    cd ..
    echo -e "${GREEN}✓ Docker installed successfully${NC}"
else
    echo -e "${GREEN}✓ Docker is already installed${NC}"
fi
echo ""

# Check if PostgreSQL is installed on database VM
echo -e "${YELLOW}Checking PostgreSQL installation on database VM...${NC}"
if ! ssh -i ssh-keys/vm-key ubuntu@${DB_VM} "which psql" &> /dev/null; then
    echo -e "${YELLOW}⚠ PostgreSQL is not installed on database VM${NC}"
    echo "You need to run database-setup.yml first"
    echo "Run: cd ansible && ansible-playbook database-setup.yml"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is installed${NC}"
echo ""

# Warning about password configuration
echo -e "${RED}=========================================${NC}"
echo -e "${RED}IMPORTANT SECURITY NOTICE${NC}"
echo -e "${RED}=========================================${NC}"
echo -e "${YELLOW}Before proceeding, you should:${NC}"
echo ""
echo "1. Edit ansible/playbooks/services/n8n-setup.yml and change:"
echo "   - n8n_db_password (line 9)"
echo "   - n8n_encryption_key (line 74)"
echo ""
echo "2. Generate a secure encryption key:"
echo "   ${BLUE}openssl rand -hex 16${NC}"
echo ""
echo "3. Optionally customize timezone and webhook URL"
echo ""
read -p "Have you configured secure passwords? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please update the passwords in ansible/playbooks/services/n8n-setup.yml first${NC}"
    echo "Then run this script again"
    exit 1
fi
echo ""

# Run the Ansible playbook
echo -e "${BLUE}Setting up n8n workflow automation...${NC}"
cd ansible
ansible-playbook playbooks/services/n8n-setup.yml

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}n8n Setup Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${BLUE}Access n8n:${NC}"
    echo "  URL: http://192.168.100.230:5678"
    echo ""
    echo -e "${BLUE}First-time setup:${NC}"
    echo "  1. Open the URL in your browser"
    echo "  2. Create your owner account (first user to register becomes owner)"
    echo "  3. Start creating workflows!"
    echo ""
    echo -e "${BLUE}Management commands (on n8n VM):${NC}"
    echo "  n8n-start   - Start n8n"
    echo "  n8n-stop    - Stop n8n"
    echo "  n8n-restart - Restart n8n"
    echo "  n8n-logs    - View logs"
    echo "  n8n-status  - Check status"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  https://docs.n8n.io/"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  • Set up reverse proxy with SSL for production"
    echo "  • Enable N8N_BASIC_AUTH for additional security"
    echo "  • Configure webhooks to use your domain"
    echo "  • Add n8n metrics to Prometheus (optional)"
else
    echo ""
    echo -e "${RED}n8n setup failed. Check the output above for errors.${NC}"
    exit 1
fi
