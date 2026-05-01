#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Kubernetes Dashboard Installation${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Change to project root if running from script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

K8S_MASTER="192.168.100.201"

# Check if k8s-master is reachable
echo -e "${YELLOW}Checking k8s-master connectivity...${NC}"
if ! ssh -o ConnectTimeout=5 -i ssh-keys/vm-key ubuntu@${K8S_MASTER} "echo 'Connected'" &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to k8s-master at ${K8S_MASTER}${NC}"
    echo "Please ensure:"
    echo "  1. K8s master VM is running"
    echo "  2. SSH access is configured"
    echo "  3. K3s is installed (run k3s-cluster-setup.yml first)"
    exit 1
fi
echo -e "${GREEN}✓ K8s master is reachable${NC}"
echo ""

# Check if K3s is running
echo -e "${YELLOW}Checking if K3s is running...${NC}"
if ssh -i ssh-keys/vm-key ubuntu@${K8S_MASTER} "sudo systemctl is-active k3s" &> /dev/null; then
    echo -e "${GREEN}✓ K3s is running${NC}"
else
    echo -e "${RED}ERROR: K3s is not running on k8s-master${NC}"
    echo "Please run the K3s cluster setup first:"
    echo "  cd ansible"
    echo "  ansible-playbook playbooks/kubernetes/k3s-cluster-setup.yml"
    exit 1
fi
echo ""

# Run the Ansible playbook
echo -e "${BLUE}Installing Kubernetes Dashboard...${NC}"
cd ansible
ansible-playbook playbooks/kubernetes/k8s-dashboard-setup.yml

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Dashboard Installation Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    
    # Check if token file was copied
    if [ -f "../k8s-dashboard-token.txt" ]; then
        echo -e "${YELLOW}Access Token:${NC}"
        cat ../k8s-dashboard-token.txt
        echo ""
        echo ""
        echo -e "${YELLOW}Token saved to: k8s-dashboard-token.txt${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}Quick Access (choose one):${NC}"
    echo ""
    echo -e "${GREEN}1. SSH Tunnel (recommended for remote access):${NC}"
    if [ -f "../script/dashboard-tunnel.sh" ]; then
        echo "   ./script/dashboard-tunnel.sh"
    else
        echo "   ssh -L 8443:localhost:30443 -i ssh-keys/vm-key ubuntu@192.168.100.201"
    fi
    echo "   Then visit: https://localhost:8443"
    echo ""
    echo -e "${GREEN}2. Direct NodePort (local network only):${NC}"
    echo "   https://192.168.100.201:30443"
    echo ""
    echo -e "${GREEN}3. kubectl proxy (if you have kubeconfig locally):${NC}"
    echo "   export KUBECONFIG=./kubeconfig"
    echo "   kubectl proxy"
    echo "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    echo ""
    echo -e "${YELLOW}Note: Use 'Token' authentication and paste the token when accessing the dashboard${NC}"
else
    echo -e "${RED}Dashboard installation failed${NC}"
    exit 1
fi
