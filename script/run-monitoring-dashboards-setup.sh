#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Grafana Dashboards Auto-Provisioning${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Change to project root if running from script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

MONITORING_VM="192.168.100.220"

# Check if monitoring VM is reachable
echo -e "${YELLOW}Checking monitoring VM connectivity...${NC}"
if ! ssh -o ConnectTimeout=5 -i ssh-keys/vm-key ubuntu@${MONITORING_VM} "echo 'Connected'" &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to monitoring VM at ${MONITORING_VM}${NC}"
    echo "Please ensure:"
    echo "  1. Monitoring VM is running"
    echo "  2. SSH access is configured"
    echo "  3. Run ./run-monitoring-setup.sh first to set up the monitoring stack"
    exit 1
fi
echo -e "${GREEN}✓ Monitoring VM is reachable${NC}"
echo ""

# Check if monitoring stack is running
echo -e "${YELLOW}Checking if monitoring stack is running...${NC}"
if ssh -i ssh-keys/vm-key ubuntu@${MONITORING_VM} "docker ps | grep -q grafana" 2>/dev/null; then
    echo -e "${GREEN}✓ Grafana is running${NC}"
else
    echo -e "${YELLOW}⚠ Grafana is not running${NC}"
    echo "The monitoring stack should be running first."
    echo "Run ./run-monitoring-setup.sh to start the monitoring stack."
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Run the Ansible playbook
echo -e "${BLUE}Provisioning Grafana dashboards...${NC}"
cd ansible
ansible-playbook playbooks/services/monitoring-dashboards-setup.yml

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Dashboard provisioning completed!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${BLUE}Access your dashboards:${NC}"
    echo "  URL: http://192.168.100.220:3000"
    echo "  Login: admin / admin"
    echo ""
    echo -e "${BLUE}Dashboards location:${NC}"
    echo "  Navigate to: Dashboards > Browse > Homelab folder"
    echo ""
    echo -e "${BLUE}Available dashboards:${NC}"
    echo "  • Node Exporter Full - Complete system metrics"
    echo "  • Node Exporter Dashboard - System overview"
    echo "  • Prometheus 2.0 Overview"
    echo "  • Kubernetes Cluster Monitoring"
    echo "  • Kubernetes Nodes Monitoring"
    echo "  • Docker Container Monitoring"
    echo "  • Docker and System Monitoring"
    echo "  • PostgreSQL Database Dashboard"
    echo ""
    echo -e "${YELLOW}Note:${NC} Some dashboards may require additional exporters"
    echo "      to be installed on target systems to display data."
else
    echo ""
    echo -e "${RED}Dashboard provisioning failed. Check the output above for errors.${NC}"
    exit 1
fi
