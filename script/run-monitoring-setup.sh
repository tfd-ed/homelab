#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Monitoring Stack Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "ansible/playbooks/services/monitoring-setup.yml" ]; then
    echo -e "${RED}ERROR: Please run this script from the project root directory${NC}"
    exit 1
fi

# Check if monitoring VM is accessible
echo -e "${YELLOW}Checking monitoring VM connectivity...${NC}"
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 -i ssh-keys/vm-key ubuntu@192.168.100.220 'exit 0'; then
    echo -e "${RED}ERROR: Cannot connect to monitoring VM (192.168.100.220)${NC}"
    echo "Please ensure:"
    echo "  1. The VM is running"
    echo "  2. SSH access is configured"
    echo "  3. The VM is accessible from this machine"
    exit 1
fi
echo -e "${GREEN}✓ Monitoring VM is accessible${NC}"
echo ""

# Check if Docker is installed
echo -e "${YELLOW}Checking if Docker is installed on monitoring VM...${NC}"
if ! ssh -i ssh-keys/vm-key ubuntu@192.168.100.220 'which docker' > /dev/null 2>&1; then
    echo -e "${YELLOW}Docker not found. Installing Docker first...${NC}"
    cd ansible
    ansible-playbook playbooks/infrastructure/docker-setup.yml --limit monitoring
    cd ..
fi
echo -e "${GREEN}✓ Docker is installed${NC}"
echo ""

# Change to project root if running from script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Run the monitoring setup playbook
echo -e "${YELLOW}Deploying Prometheus + Grafana monitoring stack...${NC}"
cd ansible
ansible-playbook playbooks/services/monitoring-setup.yml

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Monitoring Stack Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Access URLs:${NC}"
    echo -e "  Prometheus: ${YELLOW}http://192.168.100.220:9090${NC}"
    echo -e "  Grafana:    ${YELLOW}http://192.168.100.220:3000${NC}"
    echo ""
    echo -e "${GREEN}Grafana Credentials:${NC}"
    echo -e "  Username: ${YELLOW}admin${NC}"
    echo -e "  Password: ${YELLOW}admin${NC} ${RED}(CHANGE THIS!)${NC}"
    echo ""
    echo -e "${YELLOW}Recommended Grafana Dashboards:${NC}"
    echo "  - 1860: Node Exporter Full"
    echo "  - 3662: Prometheus 2.0 Overview"
    echo "  - 11074: Node Exporter for Prometheus"
    echo ""
else
    echo ""
    echo -e "${RED}Setup failed. Check the error messages above.${NC}"
    exit 1
fi
