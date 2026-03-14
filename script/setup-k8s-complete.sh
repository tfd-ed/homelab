#!/bin/bash

# Complete setup script for K8s cluster management and CI/CD
# Run this after your VMs are provisioned with Terraform

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Homelab K8s & CI/CD Complete Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}[1/6] Checking prerequisites...${NC}"
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}Error: ansible is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Warning: kubectl not found. Install it for local cluster management.${NC}"
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"
echo ""

# Step 1: Setup K3s cluster
echo -e "${BLUE}[2/6] Setting up K3s cluster...${NC}"
read -p "Do you want to setup/update the K3s cluster? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd ansible
    ansible-playbook k3s-cluster-setup.yml
    cd ..
    echo -e "${GREEN}✓ K3s cluster ready${NC}"
else
    echo -e "${YELLOW}Skipping K3s setup${NC}"
fi
echo ""

# Step 2: Install ArgoCD
echo -e "${BLUE}[3/6] Installing ArgoCD (GitOps)...${NC}"
read -p "Do you want to install ArgoCD? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd ansible
    ansible-playbook argocd-setup.yml
    cd ..
    echo ""
    echo -e "${GREEN}✓ ArgoCD installed${NC}"
    echo -e "${YELLOW}Important: Save the ArgoCD admin password shown above!${NC}"
else
    echo -e "${YELLOW}Skipping ArgoCD installation${NC}"
fi
echo ""

# Step 3: Setup Cloudflare Tunnel
echo -e "${BLUE}[4/6] Setting up Cloudflare Tunnel for remote access...${NC}"
read -p "Do you want to setup Cloudflare Tunnel for K8s API access? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./setup-cloudflare-tunnel.sh
    echo -e "${GREEN}✓ Cloudflare Tunnel configured${NC}"
else
    echo -e "${YELLOW}Skipping Cloudflare Tunnel setup${NC}"
    echo "Note: You won't be able to access the cluster from outside your network"
fi
echo ""

# Step 4: Deploy base K8s resources
echo -e "${BLUE}[5/6] Deploying base Kubernetes resources...${NC}"
read -p "Do you want to deploy base resources (namespaces, ingress-nginx)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    export KUBECONFIG=./kubeconfig
    
    echo "Deploying namespaces..."
    kubectl apply -k k8s/base/
    
    echo "Deploying Ingress NGINX..."
    kubectl apply -k k8s/infrastructure/ingress-nginx/
    
    echo "Waiting for Ingress NGINX to be ready..."
    kubectl wait --for=condition=Ready pods --all -n ingress-nginx --timeout=300s
    
    echo -e "${GREEN}✓ Base resources deployed${NC}"
else
    echo -e "${YELLOW}Skipping base resources deployment${NC}"
fi
echo ""

# Step 5: Setup GitHub Actions Runner
echo -e "${BLUE}[6/6] Setting up GitHub Actions runner...${NC}"
read -p "Do you want to setup GitHub Actions self-hosted runner? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd ansible
    ansible-playbook github-runner-setup.yml
    cd ..
    echo ""
    echo -e "${GREEN}✓ GitHub Actions runner setup initiated${NC}"
    echo -e "${YELLOW}Follow the instructions above to complete runner registration${NC}"
else
    echo -e "${YELLOW}Skipping GitHub Actions runner setup${NC}"
fi
echo ""

# Final summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Update ArgoCD applications with your GitHub repo URL:"
echo "   Edit: k8s/argocd/applications.yaml"
echo ""
echo "2. Push k8s/ directory to your GitHub repository:"
echo "   git add k8s/ .github/"
echo "   git commit -m 'Add K8s manifests and CI/CD'"
echo "   git push"
echo ""
echo "3. Add GitHub Secrets for CI/CD:"
echo "   See: .github/SECRETS.md"
echo ""
echo "4. Access your services:"
if kubectl get namespace argocd &> /dev/null 2>&1; then
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "30443")
    echo "   ArgoCD: https://192.168.100.201:${ARGOCD_PORT}"
fi
echo "   K8s Dashboard: kubectl proxy (if installed)"
echo ""
echo "5. Test remote access (if Cloudflare tunnel is setup):"
echo "   export KUBECONFIG=./kubeconfig"
echo "   kubectl get nodes"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
echo ""
