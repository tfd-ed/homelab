# Homelab Journey

Welcome to my homelab infrastructure repository! This is the central hub for documenting my homelab setup, configurations, and learnings.

> **🆕 Recent Update:** Ansible playbooks are now organized into categorized subdirectories for better maintainability! See [ansible/playbooks/](ansible/playbooks/) for the new structure.
> 
> **📚 Documentation Consolidated:** All documentation (hardware specs, setup guides, quick reference) is now integrated into this README for easier navigation.

## 📋 Table of Contents

- [Hardware Specifications](#-hardware-specifications)
- [Infrastructure Overview](#%EF%B8%8F-infrastructure-overview)
- [Repository Structure](#-repository-structure)
- [Quick Start](#-quick-start)
- [Complete Setup Guide](#-complete-setup-guide)
- [Operations & Quick Reference](#-operations--quick-reference)
- [Security](#-security)
- [Remote Access](#-remote-access)
- [Monitoring](#-monitoring)
- [Workflow Automation](#-workflow-automation-n8n)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)
- [Planned Improvements](#-planned-improvements)

## 💻 Hardware Specifications

### Physical Server

**Model:** Mini PC - Compact Homelab Server  
**CPU:** AMD Ryzen 7 7730U
- 8 Cores / 16 Threads
- Base Clock: 2.0 GHz
- Boost Clock: up to 4.5 GHz
- L1 Cache: 512 KB (64KB × 8)
- L2 Cache: 4 MB (512KB × 8)
- L3 Cache: 16 MB (shared)
- TDP: 15-28W (configurable)
- Architecture: Zen 3+ (6nm)

**Memory:** 64 GB DDR4 RAM
- Type: DDR4 SO-DIMM
- Speed: 3200 MHz
- Configuration: Dual Channel
- Maximum Capacity: 64 GB

**Storage:** 1 TB NVMe SSD
- Type: M.2 2280 NVMe PCIe Gen 3.0
- Read Speed: ~3500 MB/s
- Write Speed: ~3000 MB/s
- TBW: High endurance model

**Graphics:** AMD Radeon Graphics
- Integrated GPU (Ryzen 7730U)
- Cores: 8 CUs (Compute Units)
- Architecture: RDNA 2
- Max Frequency: 2.0 GHz
- Display Support: Dual 4K@60Hz or Single 8K@30Hz

**Networking:**
- WiFi: WiFi 6E (802.11ax) - MediaTek RZ616
  - Max Speed: 2.4 Gbps
  - Bands: 2.4GHz, 5GHz, 6GHz
- Bluetooth: 5.2
- Ethernet: Dual 2.5 Gigabit LAN (Realtek RTL8125)
  - Link Aggregation capable
  - Redundancy/Failover support

**Ports & Connectivity:**
- 4x USB 3.2 Gen2 (10 Gbps)
- 2x USB Type-C (with DisplayPort Alt Mode & Power Delivery)
- 1x HDMI 2.0 (4K@60Hz)
- 1x DisplayPort 1.4 (8K@30Hz or 4K@120Hz)
- 2x 2.5G Ethernet RJ45
- 3.5mm Audio Combo Jack
- WiFi 6E + Bluetooth 5.2

**Power:**
- Input: DC 19V / 3.42A (65W adapter)
- Power Consumption:
  - Idle: ~10-15W
  - Load: ~45-55W
  - Max: ~65W

**Physical Dimensions:**
- Size: 128.8mm (W) × 127mm (D) × 47.8mm (H)
- Weight: ~528g (bare unit), ~850g (with adapter)
- Form Factor: Mini PC / UCFF (Ultra Compact Form Factor)

**Operating System:**
- **Proxmox VE 9.1.1** (Debian-based hypervisor)
- Linux Kernel 6.8+
- ZFS or ext4 filesystem options
- Web UI: https://192.168.100.50:8006

### Why This Hardware?

✅ **Power Efficiency** - 15-28W TDP, ideal for 24/7 operation  
✅ **Performance** - 8c/16t handles multiple VMs simultaneously  
✅ **Memory** - 64GB sufficient for 8+ VMs with headroom  
✅ **Storage** - Fast NVMe for quick VM boot and low latency  
✅ **Dual NIC** - Network segregation and redundancy  
✅ **Compact** - Minimal footprint, quiet operation  
✅ **Cost Effective** - Fraction of enterprise server costs  

## 🏗️ Infrastructure Overview

This homelab runs on Proxmox VE and uses Infrastructure as Code (Terraform + Ansible) for reproducible deployments.

### Virtual Machines

| VM | IP | CPU | RAM | Disk | Purpose | Status |
|---|---|---|---|---|---|---|
| k8s-master | 192.168.100.201 | 2 | 4 GB | 50 GB | Kubernetes control plane (K3s) | ✅ Adequate |
| k8s-worker-1 | 192.168.100.202 | 4 | 14 GB | 150 GB | Kubernetes worker node | ✅ Adequate |
| k8s-worker-2 | 192.168.100.203 | 4 | 14 GB | 150 GB | Kubernetes worker node | ✅ Adequate |
| **database-vm** | **192.168.100.205** | **4** | **6 GB** | **200 GB** | **Centralized database server** | ✅ **Adequate** |
| app-gateway | 192.168.100.210 | 1 | 2 GB | 20 GB | Nginx reverse proxy | ✅ Adequate |
| monitoring | 192.168.100.220 | 2 | 6 GB | 80 GB | Prometheus, Grafana, Loki | ✅ Adequate |
| n8n | 192.168.100.230 | 2 | 6 GB | 50 GB | n8n workflow automation | ✅ Adequate |
| ci-cd | 192.168.100.240 | 2 | 5 GB | 100 GB | GitHub Actions + Docker registry | ⚠️ May need more for large builds |

**Total Resources:** 21 CPU cores, 57 GB RAM, 820 GB storage  
**Available for Host:** 3 cores (37.5%), 7 GB RAM (10.9%), ~180 GB storage

**Resource Allocation Notes:**
- All VMs have adequate resources for their intended workloads
- CI/CD VM may require additional RAM (8GB+) for heavy Docker builds
- 7GB RAM reserved for Proxmox host ensures system stability
- Storage allocation allows for data growth and logs
- Balanced allocation prevents resource contention

## 🗄️ Database Server (New!)

The dedicated database VM provides centralized database services for all projects:

- **PostgreSQL 16** (Port 5432) - Primary relational database
- **MySQL 8.0** (Port 3306) - Alternative relational database
- **MongoDB 7.0** (Port 27017) - NoSQL document database

### Why a Dedicated Database VM?

✅ **Performance** - Dedicated resources without contention  
✅ **Persistence** - Data survives container/pod restarts  
✅ **Centralization** - One server for all project databases  
✅ **Backups** - Automated daily backups with 7-day retention  
✅ **Stability** - Decoupled from application deployments  
✅ **Best Practice** - Separates stateful from stateless workloads  

## 📂 Repository Structure

```
homelab-journey/
├── terraform/           # Infrastructure provisioning
│   ├── vms.tf          # VM definitions
│   ├── variables.tf    # Configurable variables
│   └── terraform.tfvars # Your configuration
├── ansible/            # Configuration management (organized)
│   ├── inventory.ini   # VM inventory
│   ├── ansible.cfg     # Ansible configuration
│   ├── README.md       # Ansible documentation
│   └── playbooks/      # 🆕 Organized playbooks by category
│       ├── infrastructure/    # Core infrastructure setup
│       │   ├── proxmox-setup.yml
│       │   ├── qemu-agent-setup.yml
│       │   ├── docker-setup.yml
│       │   └── nginx-gateway-setup.yml
│       ├── kubernetes/        # K8s cluster deployment
│       │   └── k3s-cluster-setup.yml
│       ├── services/          # Application services
│       │   ├── database-setup.yml
│       │   ├── monitoring-setup.yml
│       │   ├── monitoring-dashboards-setup.yml
│       │   ├── n8n-setup.yml
│       │   └── cicd-setup.yml
│       └── networking/        # Network & remote access
│           ├── cloudflare-tunnel-setup.yml
│           └── github-runner-setup.yml
├── k8s/                # Kubernetes manifests
│   ├── argocd/         # ArgoCD applications
│   ├── base/           # Base resources (namespaces, secrets)
│   ├── infrastructure/ # Core services (ingress, cert-manager)
│   └── apps/           # Application deployments
├── script/             # Helper scripts
│   ├── setup-k8s-complete.sh
│   ├── setup-cloudflare-tunnel.sh
│   ├── run-monitoring-setup.sh
│   ├── run-monitoring-dashboards-setup.sh
│   ├── run-n8n-setup.sh
│   ├── run-database-setup.sh
│   ├── generate-ssh-keys.sh
│   └── cleanup-known-hosts.sh
├── .github/            # GitHub Actions workflows
│   ├── workflows/      # CI/CD pipelines
│   └── SECRETS.md      # Secret configuration guide
├── ssh-keys/           # VM SSH keys
├── diagram/            # Infrastructure diagrams
├── QUICK_REFERENCE.md  # K8s commands quick reference
├── SETUP_GUIDE.md      # Setup documentation
├── hardware.md         # Physical hardware documentation
└── vms-allocation.md   # VM resource allocation details
```

## 🚀 Quick Start

### Prerequisites

Before starting, ensure you have:
- ✅ Proxmox VE installed and configured
- ✅ VMs provisioned (see [Terraform Setup](terraform/README.md))
- ✅ SSH keys generated (run `./generate-ssh-keys.sh`)
- ✅ Ansible installed on your control machine
- ✅ GitHub account (for CI/CD setup)
- ✅ Cloudflare account (for tunnel setup)
- ✅ Domain name configured in Cloudflare DNS

### 1. Provision VMs with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Complete K8s and CI/CD Setup (One-Command 🎉)

```bash
# One-command setup for K8s cluster, ArgoCD, Cloudflare tunnel, and CI/CD
./setup-k8s-complete.sh
```

This interactive script will:
- ✅ Setup K3s cluster across all nodes
- ✅ Install ArgoCD for GitOps
- ✅ Configure Cloudflare tunnel for remote access
- ✅ Deploy base K8s resources
- ✅ Setup GitHub Actions self-hosted runner

### 3. Verify Installation

```bash
# Check cluster status
kubectl get nodes

# Verify ArgoCD is running
kubectl get pods -n argocd

# Test remote access
curl https://argocd.homelab.tfdevs.com
```

## 📖 Complete Setup Guide

This section provides detailed step-by-step instructions for manually setting up the entire infrastructure. Use the [Quick Start](#-quick-start) section for automated setup, or follow these steps for granular control.

### Step 1: Setup Kubernetes Cluster

Run the K3s cluster setup playbook to configure the master and worker nodes:

```bash
cd ansible
ansible-playbook playbooks/kubernetes/k3s-cluster-setup.yml
```

This playbook will:
- Install K3s on the master node
- Configure worker nodes to join the cluster
- Setup kubectl configuration
- Verify cluster health

**Verify:**
```bash
export KUBECONFIG=./kubeconfig
kubectl get nodes
# Should show: k8s-master, k8s-worker-1, k8s-worker-2 all Ready
```

### Step 2: Install ArgoCD

ArgoCD enables GitOps-based deployments and continuous synchronization:

```bash
# Install ArgoCD via kubectl
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
```

**Access ArgoCD UI:**
```bash
# Local access via port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 3: Deploy Base Kubernetes Resources

Deploy essential namespace and infrastructure resources:

```bash
# Deploy namespaces
kubectl apply -f k8s/base/namespaces/namespaces.yaml

# Deploy ingress-nginx controller
kubectl apply -k k8s/infrastructure/ingress-nginx/

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

**Verify Ingress Controller:**
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Step 4: Configure Cloudflare Tunnel

Setup secure remote access to your homelab without exposing ports:

```bash
# Run interactive setup script
./setup-cloudflare-tunnel.sh
```

The script will:
1. **Authenticate** with Cloudflare (opens browser)
2. **Create tunnel** named "homelab-k8s"
3. **Configure DNS routes** for your services:
   - `argocd.yourdomain.com` → ArgoCD
   - `*.k8s.yourdomain.com` → Ingress controller
4. **Copy credentials** to the master node
5. **Deploy tunnel** as a deployment in Kubernetes

**Manual Configuration:**
```bash
cd ansible

# Edit variables in cloudflare-tunnel-setup.yml:
# - cloudflare_email: your@email.com
# - cloudflare_domain: yourdomain.com
# - tunnel_name: homelab-k8s

ansible-playbook playbooks/networking/cloudflare-tunnel-setup.yml
```

**Verify Tunnel:**
```bash
# Check tunnel status in Cloudflare dashboard
# Test external access
curl https://argocd.yourdomain.com
```

### Step 5: Setup GitHub Actions Runner

Configure self-hosted runner for CI/CD automation:

```bash
cd ansible

# Get GitHub runner registration token:
# 1. Go to: https://github.com/YOUR_ORG_OR_USER/YOUR_REPO/settings/actions/runners/new
# 2. Copy the token (starts with "AAAAAA...")
# 3. Set as environment variable:
export GITHUB_RUNNER_TOKEN="YOUR_TOKEN_HERE"

# Run playbook
ansible-playbook playbooks/networking/github-runner-setup.yml

# Verify runner is connected
# Check: https://github.com/YOUR_REPO/settings/actions/runners
```

**Runner Capabilities:**
- Kubernetes deployments via kubectl
- Docker image builds and pushes
- Automated testing and validation
- Multi-stage pipelines

### Step 6: Configure GitHub Secrets

Add the following secrets to your GitHub repository for CI/CD pipelines:

**Required Secrets:**
```bash
# Repository Settings → Secrets and variables → Actions → New repository secret

# 1. KUBECONFIG - For kubectl access to your cluster
# Copy your kubeconfig file content:
cat kubeconfig
# Paste the entire content as KUBECONFIG secret

# 2. DOCKER_REGISTRY (optional)
# Value: 192.168.100.240:5000

# 3. DOCKER_USERNAME (optional, if registry has auth)
# 4. DOCKER_PASSWORD (optional, if registry has auth)
```

**GitHub Workflow Example:**
```yaml
# .github/workflows/deploy.yml
name: Deploy to K8s
on:
  push:
    paths:
      - 'k8s/**'

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Kubernetes
        env:
          KUBECONFIG_CONTENT: ${{ secrets.KUBECONFIG }}
        run: |
          echo "$KUBECONFIG_CONTENT" > /tmp/kubeconfig
          export KUBECONFIG=/tmp/kubeconfig
          kubectl apply -k k8s/apps/myapp/
```

### Step 7: Setup Additional Services

#### Database Server
```bash
# Set database passwords
export POSTGRES_PASSWORD=your_secure_password
export MYSQL_ROOT_PASSWORD=your_secure_password
export MONGO_ROOT_PASSWORD=your_secure_password

# Run playbook (or use: ./run-database-setup.sh)
ansible-playbook playbooks/services/database-setup.yml
```

#### Monitoring Stack
```bash
# Deploy Prometheus and Grafana (or use: ./run-monitoring-setup.sh)
ansible-playbook playbooks/services/monitoring-setup.yml

# Setup automated dashboards (or use: ./run-monitoring-dashboards-setup.sh)
ansible-playbook playbooks/services/monitoring-dashboards-setup.yml
```

**Auto-Provisioned Dashboards:**
- Node Exporter Full
- Kubernetes Cluster Monitoring
- Docker Container & Host Metrics
- PostgreSQL Database
- MySQL Prometheus Exporter
- MongoDB Monitoring
- NGINX Ingress Controller
- Prometheus 2.0 Stats

#### n8n Workflow Automation
```bash
# Deploy n8n (or use: ./run-n8n-setup.sh)
export N8N_BASIC_AUTH_USER=admin
export N8N_BASIC_AUTH_PASSWORD=your_password
ansible-playbook playbooks/services/n8n-setup.yml
```

### Verification Checklist

After completing setup, verify all components:

- [ ] **Cluster Health**
  ```bash
  kubectl get nodes
  # All nodes should show "Ready"
  ```

- [ ] **ArgoCD Running**
  ```bash
  kubectl get pods -n argocd
  # All pods should be "Running"
  ```

- [ ] **Ingress Controller Deployed**
  ```bash
  kubectl get pods -n ingress-nginx
  kubectl get svc -n ingress-nginx
  ```

- [ ] **Remote Access Working**
  ```bash
  curl https://argocd.yourdomain.com
  # Should return ArgoCD login page
  ```

- [ ] **GitHub Runner Connected**
  - Check: Repository Settings → Actions → Runners
  - Status should be "Idle" and green

- [ ] **CI/CD Pipeline Functional**
  ```bash
  # Make a test change to k8s/
  git commit -am "test: trigger pipeline"
  git push
  # Check Actions tab for running workflow
  ```

- [ ] **Databases Accessible**
  ```bash
  # From any VM
  psql -h 192.168.100.205 -U postgres -d postgres
  mysql -h 192.168.100.205 -u root -p
  mongosh mongodb://192.168.100.205:27017
  ```

- [ ] **Monitoring Stack Operational**
  - Prometheus: http://192.168.100.220:9090
  - Grafana: http://192.168.100.220:3000 (admin/admin)
  - Check "Homelab" folder for 8 auto-provisioned dashboards

- [ ] **n8n Accessible**
  - URL: http://192.168.100.230:5678
  - Login with configured credentials

### Daily Workflow

#### Deploying a New Application

1. **Create Kubernetes manifests:**
   ```bash
   mkdir -p k8s/apps/myapp
   ```

2. **Define resources:**
   ```yaml
   # k8s/apps/myapp/deployment.yaml
   # k8s/apps/myapp/service.yaml
   # k8s/apps/myapp/ingress.yaml
   # k8s/apps/myapp/kustomization.yaml
   ```

3. **Push to Git:**
   ```bash
   git add k8s/apps/myapp/
   git commit -m "feat: add myapp deployment"
   git push
   ```

4. **GitHub Actions automatically:**
   - Validates manifests
   - Applies to cluster
   - Sends notifications

5. **Verify deployment:**
   ```bash
   kubectl get pods -n your-namespace
   kubectl get ingress -n your-namespace
   ```

#### Making Changes

1. **Update manifests** in `k8s/apps/myapp/`
2. **Commit and push** to Git
3. **CI/CD automatically deploys** changes
4. **ArgoCD syncs** and monitors state

#### Monitoring

- **Check application logs:**
  ```bash
  kubectl logs -f deployment/myapp -n namespace
  ```

- **View resource usage:**
  ```bash
  kubectl top nodes
  kubectl top pods -namespaces
  ```

- **Access Grafana dashboards:**
  - http://192.168.100.220:3000
  - Navigate to "Homelab" folder

## 🔐 Security

- **SSH Keys:** Generated keys stored in `ssh-keys/` directory
- **Passwords:** Use environment variables for sensitive data
- **Firewall:** UFW configured on each VM
- **Network:** Isolated VLAN for homelab (optional)
- **Cloudflare Tunnel:** Secure remote access without exposing ports
- **ArgoCD RBAC:** Role-based access control for deployments
- **Sealed Secrets:** Encrypted secrets in Git

## 🌐 Remote Access

Manage your homelab from anywhere securely!

### Kubernetes API & ArgoCD
```bash
# Configure kubectl for remote access (via Cloudflare tunnel)
export KUBECONFIG=./kubeconfig
kubectl get nodes

# Access ArgoCD UI
open https://argocd.homelab.tfdevs.com
```

### SSH Access Options
- **Option 1:** Cloudflare Tunnel (recommended) - Zero trust, no ports exposed
- **Option 2:** Tailscale VPN - Mesh VPN, easy setup
- **Option 3:** WireGuard VPN - High performance, self-hosted

See [ansible/cloudflare-tunnel-k8s-setup.yml](ansible/cloudflare-tunnel-k8s-setup.yml) for K8s remote access setup.

## 📊 Monitoring

The monitoring VM (192.168.100.220) provides comprehensive observability:

- **Prometheus v2.48.1** - Metrics collection, alerting, and time-series database
- **Grafana 10.2.3** - Visualization with 8 auto-provisioned dashboards
- **Node Exporter** - System metrics (CPU, memory, disk, network)
- **30-day retention** - Historical metrics for trend analysis

**Access:** http://192.168.100.220:9090 (Prometheus) | http://192.168.100.220:3000 (Grafana)

## 🤖 Workflow Automation (n8n)

The n8n VM (192.168.100.230) provides powerful workflow automation:

- **n8n (latest)** - Self-hosted automation platform (Zapier/Make alternative)
- **PostgreSQL backend** - Persistent workflow storage on database-vm
- **Webhook support** - Create custom API endpoints and integrations
- **Visual workflow builder** - No-code/low-code automation

**Use cases:**
- CI/CD pipeline triggers and notifications
- Database backup automation and scheduling  
- Infrastructure monitoring alerts routing
- Service health checks and auto-remediation
- Data synchronization between systems
- Custom API integrations

**Access:** http://192.168.100.230:5678

## 🔄 CI/CD Pipeline

The ci-cd VM (192.168.100.240) provides continuous deployment:

- **GitHub Actions Runner** - Self-hosted runner for automated deployments
- **Docker Registry** - Private registry at `192.168.100.240:5000`
- **Kubectl + Kustomize** - Deploy to Kubernetes cluster
- **Build Tools** - Node.js, Python, Git, etc.

### Deployment Workflow

1. **Push code** to GitHub repository
2. **GitHub Actions** automatically triggers on changes to `k8s/**`
3. **Validates** manifests and Kustomize builds
4. **Deploys** to K3s cluster using kubectl
5. **ArgoCD** syncs and monitors application state

See [.github/workflows/k8s-deploy.yml](.github/workflows/k8s-deploy.yml) for the pipeline configuration

## 🗺️ Network Topology

```
Internet
   │
   ├─ Router/Gateway (192.168.100.1)
   │
   └─ Proxmox Host (192.168.100.50)
       │
       ├─ K8s Cluster (192.168.100.201-203)
       ├─ Database Server (192.168.100.205) 🆕
       ├─ Gateway (192.168.100.210)
       ├─ Monitoring (192.168.100.220)
       ├─ n8n (192.168.100.230)
       └─ CI/CD (192.168.100.240)
```

## ☸️ Kubernetes Management

### GitOps with ArgoCD

ArgoCD automatically keeps your cluster in sync with this Git repository:

```bash
# Access ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Or via Cloudflare tunnel: https://argocd.homelab.tfdevs.com

# Deploy an app via ArgoCD
kubectl apply -f k8s/argocd/applications.yaml
```

### Manual Deployment

```bash
# Deploy with Kustomize
kubectl apply -k k8s/apps/myapp/

# Deploy with kubectl
kubectl apply -f k8s/apps/myapp/deployment.yaml
```

### Common Commands

See [Operations & Quick Reference](#-operations--quick-reference) for comprehensive commands.

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# View logs
kubectl logs -f deployment/myapp -n namespace

# Scale a deployment
kubectl scale deployment/myapp --replicas=5 -n namespace

# Rollback a deployment
kubectl rollout undo deployment/myapp -n namespace
```

## 🛠️ Operations & Quick Reference

### Initial Setup Commands

```bash
# Complete K8s setup (includes ArgoCD, base resources, Cloudflare tunnel)
./setup-k8s-complete.sh

# Setup monitoring stack
./run-monitoring-setup.sh

# Setup automated Grafana dashboards
./run-monitoring-dashboards-setup.sh

# Setup database server
./run-database-setup.sh

# Setup n8n workflow automation
./run-n8n-setup.sh

# Configure kubectl locally
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

### Daily Operations

#### Cluster Status
```bash
# Check node health
kubectl get nodes
kubectl describe node k8s-worker-1

# View all resources
kubectl get all --all-namespaces

# Check cluster component status
kubectl get componentstatuses

# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

#### Application Management
```bash
# List all pods
kubectl get pods -n your-namespace

# View deployment status
kubectl get deployments -n your-namespace

# Check services
kubectl get svc -n your-namespace

# View ingress routes
kubectl get ingress --all-namespaces

# Port forward for local access
kubectl port-forward svc/myapp 8080:80 -n your-namespace
```

#### Logs and Debugging
```bash
# View pod logs
kubectl logs pod-name -n namespace

# Follow logs in real-time
kubectl logs -f deployment/myapp -n namespace

# View logs from previous container instance
kubectl logs pod-name --previous -n namespace

# Get last 100 lines
kubectl logs --tail=100 pod-name -n namespace

# View logs from specific container in multi-container pod
kubectl logs pod-name -c container-name -n namespace
```

### Common Tasks

#### Add a New Application

1. **Create manifests:**
```bash
mkdir -p k8s/apps/myapp
```

2. **Create deployment:**
```yaml
# k8s/apps/myapp/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: apps
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myregistry/myapp:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

3. **Create service:**
```yaml
# k8s/apps/myapp/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: apps
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

4. **Create ingress:**
```yaml
# k8s/apps/myapp/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: apps
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.k8s.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
  tls:
  - secretName: myapp-tls
    hosts:
    - myapp.k8s.yourdomain.com
```

5. **Create kustomization:**
```yaml
# k8s/apps/myapp/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml

namespace: apps
```

6. **Create ArgoCD application:**
```yaml
# k8s/argocd/myapp-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/homelab-journey.git
    targetRevision: HEAD
    path: k8s/apps/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

7. **Deploy:**
```bash
# Commit to Git
git add k8s/apps/myapp k8s/argocd/myapp-application.yaml
git commit -m "feat: add myapp deployment"
git push

# Apply ArgoCD application
kubectl apply -f k8s/argocd/myapp-application.yaml

# Or deploy manually
kubectl apply -k k8s/apps/myapp/
```

#### Update an Application

```bash
# Update image version
kubectl set image deployment/myapp myapp=myregistry/myapp:v2.0 -n apps

# Or edit deployment directly
kubectl edit deployment myapp -n apps

# View rollout status
kubectl rollout status deployment/myapp -n apps

# View rollout history
kubectl rollout history deployment/myapp -n apps
```

#### Rollback a Deployment

```bash
# Rollback to previous version
kubectl rollout undo deployment/myapp -n apps

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2 -n apps

# Check rollout history
kubectl rollout history deployment/myapp -n apps
```

#### Scale Applications

```bash
# Scale to specific number of replicas
kubectl scale deployment/myapp --replicas=5 -n apps

# Autoscale based on CPU
kubectl autoscale deployment/myapp --min=3 --max=10 --cpu-percent=80 -n apps

# View HPA status
kubectl get hpa -n apps
```

#### Debug Pods

```bash
# Get pod details
kubectl describe pod pod-name -n namespace

# Execute command in pod
kubectl exec -it pod-name -n namespace -- /bin/bash

# Execute command in specific container
kubectl exec -it pod-name -c container-name -n namespace -- /bin/sh

# Copy files from pod
kubectl cp namespace/pod-name:/path/to/file ./local-file

# Copy files to pod
kubectl cp ./local-file namespace/pod-name:/path/to/file

# View pod resource usage
kubectl top pod pod-name -n namespace
```

#### Manage Secrets

```bash
# Create generic secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass \
  -n namespace

# Create from file
kubectl create secret generic my-secret \
  --from-file=./credentials.json \
  -n namespace

# View secrets (values are base64 encoded)
kubectl get secret my-secret -o yaml -n namespace

# Decode secret value
kubectl get secret my-secret -o jsonpath='{.data.password}' -n namespace | base64 -d

# Delete secret
kubectl delete secret my-secret -n namespace
```

#### Sealed Secrets (Recommended for GitOps)

Sealed Secrets allow you to encrypt secrets and store them safely in Git:

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI (macOS)
brew install kubeseal

# Create a secret locally (not applied)
kubectl create secret generic my-secret \
  --from-literal=password=verysecret \
  --dry-run=client -o yaml > /tmp/secret.yaml

# Encrypt it with kubeseal
kubeseal --format=yaml < /tmp/secret.yaml > k8s/apps/myapp/sealed-secret.yaml

# Commit encrypted secret to Git
git add k8s/apps/myapp/sealed-secret.yaml
git commit -m "feat: add sealed secret"
git push

# The sealed-secrets controller automatically decrypts it in the cluster
```

### n8n Workflow Automation Management

#### Access n8n
```bash
# Web UI
open http://192.168.100.230:5678

# Or via SSH tunnel
ssh -L 5678:localhost:5678 user@192.168.100.230
open http://localhost:5678
```

#### Manage n8n Service

```bash
# SSH into n8n VM
ssh user@192.168.100.230

# Start n8n
n8n-start
# or: sudo docker-compose -f /opt/n8n/docker-compose.yml up -d

# Stop n8n
n8n-stop
# or: sudo docker-compose -f /opt/n8n/docker-compose.yml down

# Restart n8n
n8n-restart
# or: sudo docker-compose -f /opt/n8n/docker-compose.yml restart

# View logs
n8n-logs
# or: sudo docker-compose -f /opt/n8n/docker-compose.yml logs -f

# Check status
n8n-status
# or: sudo docker ps | grep n8n
```

#### Common n8n Use Cases

1. **CI/CD Integration:**
   - Trigger deployments on specific events
   - Send notifications to Slack/Discord/Email on pipeline status
   - Create Jira tickets for failed deployments

2. **Database Automation:**
   - Automated backups with retention policies
   - Data validation and cleanup jobs
   - Sync data between systems

3. **Monitoring Alerts:**
   - Forward Prometheus alerts to multiple channels
   - Create incidents in PagerDuty/Opsgenie
   - Auto-remediation workflows (restart services, scale resources)

4. **Infrastructure Automation:**
   - Scheduled VM snapshots
   - Automated certificate renewals
   - Resource optimization (scale down during off-hours)

5. **Data Integration:**
   - Sync GitHub issues with project management tools
   - Aggregate logs from multiple sources
   - Data transformation and ETL pipelines

6. **Custom Webhooks:**
   - Create custom API endpoints for integrations
   - Trigger workflows from external systems
   - Build workflow orchestration for complex processes

#### n8n Configuration Files

- **Docker Compose:** `/opt/n8n/docker-compose.yml`
- **Data Directory:** `/opt/n8n/data/`
- **Environment:** `/opt/n8n/.env`
- **Database:** PostgreSQL on database-vm (192.168.100.205)

### Monitoring Services

#### Prometheus
```bash
# Access Prometheus UI
open http://192.168.100.220:9090

# View targets
open http://192.168.100.220:9090/targets

# Query metrics examples:
# - node_cpu_seconds_total
# - node_memory_MemAvailable_bytes
# - container_cpu_usage_seconds_total
# - kube_pod_status_phase
```

#### Grafana
```bash
# Access Grafana UI
open http://192.168.100.220:3000

# Default credentials:
# Username: admin
# Password: admin (change on first login)

# Dashboards location:
# Home → Dashboards → Homelab folder
```

#### Automated Dashboard Provisioning

Install 8 pre-configured dashboards automatically:

```bash
# Run dashboard setup
./run-monitoring-dashboards-setup.sh

# Or manually
cd ansible
ansible-playbook playbooks/services/monitoring-dashboards-setup.yml
```

**Installed Dashboards:**
1. **Node Exporter Full** (ID: 1860) - Complete system metrics
2. **Kubernetes Cluster Monitoring** (ID: 7249) - K8s overview
3. **Docker Container & Host Metrics** (ID: 10619) - Container stats
4. **PostgreSQL Database** (ID: 9628) - Database performance
5. **MySQL Prometheus Exporter** (ID: 7362) - MySQL metrics
6. **MongoDB Monitoring** (ID: 2583) - MongoDB stats
7. **NGINX Ingress Controller** (ID: 9614) - Ingress metrics
8. **Prometheus 2.0 Stats** (ID: 3662) - Prometheus internals

All dashboards are automatically imported into the "Homelab" folder in Grafana.

#### Resource Usage

```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces

# Sort by CPU
kubectl top pods --all-namespaces --sort-by=cpu

# Sort by memory
kubectl top pods --all-namespaces --sort-by=memory

# View specific namespace
kubectl top pods -n apps
```

## � Troubleshooting

### Pod Not Starting

**Issue:** Pod stuck in `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff` status

**Diagnostic Steps:**

```bash
# Get pod status
kubectl get pods -n namespace

# View pod details and events
kubectl describe pod pod-name -n namespace

# Check pod logs
kubectl logs pod-name -n namespace

# Check previous container logs (if pod restarted)
kubectl logs pod-name --previous -n namespace
```

**Common Causes & Solutions:**

1. **Insufficient Resources:**
   ```bash
   # Check node resources
   kubectl top nodes
   kubectl describe node node-name
   
   # Reduce resource requests in deployment:
   resources:
     requests:
       memory: "128Mi"  # Reduce if needed
       cpu: "100m"      # Reduce if needed
   ```

2. **Image Pull Errors:**
   ```bash
   # Verify image name and tag
   kubectl describe pod pod-name -n namespace | grep Image
   
   # Check image pull secrets (if using private registry)
   kubectl get secrets -n namespace
   
   # Create image pull secret:
   kubectl create secret docker-registry regcred \
     --docker-server=registry.homelab.local \
     --docker-username=user \
     --docker-password=pass \
     -n namespace
   ```

3. **Configuration Errors:**
   ```bash
   # Validate YAML syntax
   kubectl apply --dry-run=client -f deployment.yaml
   
   # Check ConfigMaps and Secrets exist
   kubectl get configmaps -n namespace
   kubectl get secrets -n namespace
   ```

4. **Volume Mount Issues:**
   ```bash
   # Check PersistentVolumeClaims
   kubectl get pvc -n namespace
   
   # Describe PVC for details
   kubectl describe pvc pvc-name -n namespace
   ```

### Service Not Accessible

**Issue:** Cannot access service via ClusterIP, NodePort, or Ingress

**Diagnostic Steps:**

```bash
# Check service endpoints
kubectl get svc -n namespace
kubectl describe svc service-name -n namespace

# Verify endpoints are populated
kubectl get endpoints service-name -n namespace

# Check if pods are ready
kubectl get pods -n namespace -l app=myapp

# Test service from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://service-name.namespace.svc.cluster.local
```

**Solutions:**

1. **No Endpoints:**
   - Verify pod labels match service selector
   - Check if pods are in `Running` and `Ready` state

2. **Ingress Not Working:**
   ```bash
   # Check ingress status
   kubectl get ingress -n namespace
   kubectl describe ingress ingress-name -n namespace
   
   # Verify ingress controller is running
   kubectl get pods -n ingress-nginx
   
   # Check ingress controller logs
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

3. **DNS Issues:**
   ```bash
   # Test CoreDNS
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   
   # Test DNS resolution from pod
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
   ```

### Remote Access Issues

**Issue:** Cannot reach ArgoCD or K8s API from external network

**Solutions:**

1. **Cloudflare Tunnel Not Working:**
   ```bash
   # Check tunnel status on k8s-master
   ssh user@192.168.100.201
   sudo systemctl status cloudflared
   
   # View tunnel logs
   sudo journalctl -u cloudflared -f
   
   # Restart tunnel
   sudo systemctl restart cloudflared
   
   # Verify tunnel in Cloudflare dashboard
   # https://dash.cloudflare.com → Zero Trust → Access → Tunnels
   ```

2. **Kubeconfig Issues:**
   ```bash
   # Verify kubeconfig file
   cat kubeconfig
   
   # Test connection
   export KUBECONFIG=./kubeconfig
   kubectl cluster-info
   
   # Re-copy kubeconfig from master
   scp user@192.168.100.201:/etc/rancher/k3s/k3s.yaml ./kubeconfig
   
   # Update server URL to Cloudflare domain or public IP
   # Edit kubeconfig and change:
   # server: https://127.0.0.1:6443
   # to: https://k8s.yourdomain.com:6443
   ```

3. **ArgoCD Not Accessible:**
   ```bash
   # Check ArgoCD pods
   kubectl get pods -n argocd
   
   # Verify service
   kubectl get svc -n argocd
   
   # Port forward for local testing
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   open https://localhost:8080
   
   # Check ingress (if configured)
   kubectl get ingress -n argocd
   ```

### GitHub Actions Not Deploying

**Issue:** CI/CD pipeline fails or doesn't trigger

**Diagnostic Steps:**

1. **Check Runner Status:**
   ```bash
   # On ci-cd VM
   ssh user@192.168.100.240
   sudo ./svc.sh status
   
   # View runner logs
   tail -f _diag/Runner_*.log
   
   # Restart runner if needed
   sudo ./svc.sh stop
   sudo ./svc.sh start
   ```

2. **Verify GitHub Secrets:**
   - Go to: Repository → Settings → Secrets and variables → Actions
   - Ensure `KUBECONFIG` secret is set correctly
   - Test kubeconfig by copying its content and running locally:
     ```bash
     echo "$KUBECONFIG_CONTENT" > /tmp/test-kubeconfig
     export KUBECONFIG=/tmp/test-kubeconfig
     kubectl get nodes
     ```

3. **Check Workflow Syntax:**
   ```bash
   # Validate workflow file locally
   # Install actionlint: brew install actionlint
   actionlint .github/workflows/*.yml
   ```

4. **View Workflow Logs:**
   - GitHub: Actions tab → Select failed workflow → View logs
   - Common issues:
     - Invalid KUBECONFIG format
     - Network connectivity to cluster
     - Insufficient permissions
     - Kubectl command errors

### ArgoCD Sync Issues

**Issue:** ArgoCD shows "OutOfSync" or sync fails

**Solutions:**

```bash
# Force sync
kubectl patch application myapp -n argocd \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'

# Or use ArgoCD CLI
argocd app sync myapp --force

# View sync status
argocd app get myapp

# View application details
kubectl describe application myapp -n argocd

# Check application logs
kubectl logs -n argocd deployment/argocd-application-controller

# Manual sync via UI
# ArgoCD UI → Applications → myapp → Sync → Force
```

**Common Sync Issues:**
- **Git repository unreachable:** Check repo URL and credentials
- **Invalid manifests:** Validate YAML syntax
- **Resource conflicts:** Delete conflicting resources manually
- **Hook failures:** Check hook job logs

### Database Connection Issues

**Issue:** Applications cannot connect to databases on database-vm

**Diagnostic Steps:**

```bash
# Test database connectivity from K8s pod
kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- \
  psql -h 192.168.100.205 -U postgres -d postgres

# Test from local machine
psql -h 192.168.100.205 -U postgres -d postgres
mysql -h 192.168.100.205 -u root -p
mongosh mongodb://192.168.100.205:27017

# Check database services are running
ssh user@192.168.100.205
sudo systemctl status postgresql
sudo systemctl status mysql
sudo systemctl status mongod

# Check firewall rules
sudo ufw status
# Should show ports 5432, 3306, 27017 allowed

# Verify databases are listening on all interfaces
sudo netstat -tlnp | grep -E '5432|3306|27017'
# Should show 0.0.0.0:PORT, not 127.0.0.1:PORT
```

**Solutions:**

1. **PostgreSQL Not Allowing Remote Connections:**
   ```bash
   # Edit pg_hba.conf
   sudo nano /etc/postgresql/16/main/pg_hba.conf
   # Add: host all all 192.168.100.0/24 scram-sha-256
   
   # Edit postgresql.conf
   sudo nano /etc/postgresql/16/main/postgresql.conf
   # Set: listen_addresses = '*'
   
   # Restart PostgreSQL
   sudo systemctl restart postgresql
   ```

2. **MySQL Binding to Localhost Only:**
   ```bash
   # Edit MySQL config
   sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
   # Set: bind-address = 0.0.0.0
   
   # Restart MySQL
   sudo systemctl restart mysql
   
   # Grant remote access
   mysql -u root -p
   GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'password';
   FLUSH PRIVILEGES;
   ```

3. **MongoDB Not Allowing Remote Connections:**
   ```bash
   # Edit mongod.conf
   sudo nano /etc/mongod.conf
   # Set: bindIp: 0.0.0.0
   
   # Restart MongoDB
   sudo systemctl restart mongod
   ```

### High Resource Usage

**Issue:** Node or pod consuming excessive CPU/memory

**Diagnostic Steps:**

```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# View detailed node metrics
kubectl describe node node-name

# Check for resource limits
kubectl describe deployment deployment-name -n namespace | grep -A 5 Limits
```

**Solutions:**

1. **Adjust Resource Limits:**
   ```yaml
   resources:
     requests:
       memory: "256Mi"
       cpu: "200m"
     limits:
       memory: "512Mi"
       cpu: "500m"
   ```

2. **Scale Down Non-Critical Pods:**
   ```bash
   kubectl scale deployment/myapp --replicas=1 -n namespace
   ```

3. **Restart Problematic Pods:**
   ```bash
   kubectl rollout restart deployment/myapp -n namespace
   ```

4. **Check for Memory Leaks:**
   ```bash
   # Monitor pod over time
   watch kubectl top pod pod-name -n namespace
   
   # View Grafana dashboards for trends
   # http://192.168.100.220:3000
   ```

### Monitoring Not Showing Data

**Issue:** Prometheus has no data or Grafana shows "No Data"

**Solutions:**

```bash
# Check Prometheus targets
open http://192.168.100.220:9090/targets
# All targets should show "UP" status

# Verify node exporter is running on all VMs
ssh user@192.168.100.201
sudo systemctl status node_exporter

# Check Prometheus config
ssh user@192.168.100.220
sudo cat /etc/prometheus/prometheus.yml

# Restart Prometheus
sudo systemctl restart prometheus

# Verify Grafana datasource
# Grafana → Configuration → Data Sources → Prometheus
# URL should be: http://localhost:9090
# Click "Save & Test" → should show green success

# Re-import dashboards if needed
./run-monitoring-dashboards-setup.sh
```

### n8n Workflows Not Running

**Issue:** n8n workflows not executing or erroring

**Diagnostic Steps:**

```bash
# Check n8n is running
ssh user@192.168.100.230
n8n-status

# View n8n logs
n8n-logs

# Check PostgreSQL connection (n8n uses database-vm)
psql -h 192.168.100.205 -U n8n -d n8n

# Restart n8n
n8n-restart

# Access n8n UI
open http://192.168.100.230:5678
```

**Common Issues:**
- **Database connection:** Verify database-vm is accessible
- **Webhook failures:** Check firewall rules and exposed ports
- **Credential errors:** Re-configure credentials in n8n UI
- **Timeout issues:** Increase workflow timeout settings

### Network Connectivity Issues

**Issue:** Pods cannot communicate with each other or external services

**Diagnostic Steps:**

```bash
# Test pod-to-pod communication
kubectl exec -it pod1 -n namespace -- ping pod2-ip

# Test external connectivity
kubectl exec -it pod-name -n namespace -- ping 8.8.8.8
kubectl exec -it pod-name -n namespace -- curl https://google.com

# Check CNI plugin (Flannel in K3s)
kubectl get pods -n kube-system -l app=flannel

# Verify network policies (if any)
kubectl get networkpolicies --all-namespaces

# Check iptables rules (on nodes)
ssh user@node-ip
sudo iptables -L -n -v
```

**Solutions:**

- Restart affected pods
- Restart CNI plugin pods
- Check K3s service on nodes: `sudo systemctl status k3s` or `sudo systemctl status k3s-agent`
- Verify routing: `ip route show`

### General Debugging Tips

1. **Always check events first:**
   ```bash
   kubectl get events -n namespace --sort-by='.lastTimestamp'
   ```

2. **Use describe for detailed info:**
   ```bash
   kubectl describe <resource-type> <resource-name> -n namespace
   ```

3. **Check logs systematically:**
   - Application logs: `kubectl logs`
   - System logs: `journalctl`
   - Service logs: `systemctl status`

4. **Isolate the issue:**
   - Test from multiple points (local, same node, different node)
   - Simplify (reduce to minimal reproduction case)
   - Compare with working examples

5. **Use debug containers:**
   ```bash
   # Run temporary debugging pod
   kubectl run debug -it --rm --image=nicolaka/netshoot --restart=Never -- bash
   ```

6. **Document and version:**
   - Keep notes of issues and solutions
   - Track configuration changes in Git
   - Use Git tags for stable states

## 📚 Documentation

This README serves as the central documentation for the entire homelab setup. Additional specialized documentation:

### Core Documentation (In This README)
- ✅ [Hardware Specifications](#-hardware-specifications) - Physical server specs
- ✅ [Infrastructure Overview](#%EF%B8%8F-infrastructure-overview) - VM allocation and architecture
- ✅ [Repository Structure](#-repository-structure) - Project organization
- ✅ [Quick Start](#-quick-start) - Fast deployment guide
- ✅ [Complete Setup Guide](#-complete-setup-guide) - Detailed step-by-step instructions
- ✅ [Operations & Quick Reference](#-operations--quick-reference) - Daily commands and procedures
- ✅ [Troubleshooting](#-troubleshooting) - Common issues and solutions

### Additional Documentation
- **[Ansible Playbooks](ansible/README.md)** - Configuration management guide (organized by category)
- **[Terraform Setup](terraform/README.md)** - VM provisioning with IaC
- **[SSH Setup](terraform/SSH_SETUP.md)** - SSH key configuration and best practices
- **[Kubernetes Management](k8s/README.md)** - K8s deployment patterns and ArgoCD

### Ansible Playbook Categories

All playbooks are organized in `ansible/playbooks/` by functional category:
- 🏗️ **[Infrastructure](ansible/playbooks/infrastructure/)** - Proxmox, Docker, Nginx, QEMU agent (4 playbooks)
- ☸️ **[Kubernetes](ansible/playbooks/kubernetes/)** - K3s cluster deployment (1 playbook)
- 🚀 **[Services](ansible/playbooks/services/)** - Databases, monitoring, n8n, CI/CD (5 playbooks)
- 🌐 **[Networking](ansible/playbooks/networking/)** - Cloudflare tunnel, GitHub runner (2 playbooks)

### Deprecated Documentation Files

The following standalone files have been consolidated into this README:
- ~~`hardware.md`~~ → See [Hardware Specifications](#-hardware-specifications)
- ~~`vms-allocation.md`~~ → See [Infrastructure Overview](#%EF%B8%8F-infrastructure-overview)
- ~~`SETUP_GUIDE.md`~~ → See [Complete Setup Guide](#-complete-setup-guide)
- ~~`QUICK_REFERENCE.md`~~ → See [Operations & Quick Reference](#-operations--quick-reference)

These files remain in the repository for historical reference but are no longer actively maintained.

## 🎯 Planned Improvements

- [x] ~~Deploy ArgoCD for GitOps~~ ✅ Complete!
- [x] ~~Implement CI/CD with GitHub Actions~~ ✅ Complete!
- [x] ~~Setup Cloudflare Tunnel for remote access~~ ✅ Complete!
- [x] ~~Implement Prometheus monitoring stack~~ ✅ Complete!
- [x] ~~Configure Grafana dashboards~~ ✅ Complete (auto-provisioned)!
- [x] ~~Deploy n8n workflow automation~~ ✅ Complete!
- [x] ~~Setup Docker Registry~~ ✅ Complete!
- [x] ~~Centralized database server~~ ✅ Complete!
- [ ] Implement Longhorn for distributed storage
- [ ] Deploy Velero for cluster backups
- [ ] Setup Cert-Manager for automated TLS certificates
- [ ] Implement network policies
- [ ] Setup Sealed Secrets for secret management
- [ ] Implement automated database migrations
- [ ] Configure SSL/TLS for all services
- [ ] Set up log aggregation (Loki + Promtail)

## 📝 Notes

This repository follows Infrastructure as Code principles:
- All infrastructure defined in code (Terraform + Ansible + Kubernetes)
- Version controlled and reproducible
- GitOps workflow with ArgoCD
- Automated CI/CD with GitHub Actions
- Secure remote access via Cloudflare Tunnel
- Documented for learning and future reference
- Designed for homelab experimentation and learning

---

**Last Updated:** December 2024  
**Homelab Status:** 🟢 Operational | ⚡ GitOps Enabled | 🚀 CI/CD Active | 📚 Documentation Consolidated
