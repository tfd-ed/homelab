# Ansible Playbooks for Homelab

This directory contains Ansible playbooks for managing the homelab infrastructure.

## 📁 Directory Structure

```
ansible/
├── README.md                    # This file
├── ansible.cfg                  # Ansible configuration
├── inventory.ini                # VM inventory and connection details
└── playbooks/                   # Organized playbooks by category
    ├── infrastructure/          # Core infrastructure setup
    │   ├── proxmox-setup.yml
    │   ├── qemu-agent-setup.yml
    │   ├── docker-setup.yml
    │   └── nginx-gateway-setup.yml
    ├── kubernetes/              # Kubernetes cluster
    │   └── k3s-cluster-setup.yml
    ├── services/                # Application services
    │   ├── database-setup.yml
    │   ├── monitoring-setup.yml
    │   ├── monitoring-dashboards-setup.yml
    │   ├── n8n-setup.yml
    │   └── cicd-setup.yml
    └── networking/              # Networking & remote access
        ├── cloudflare-tunnel-setup.yml
        └── github-runner-setup.yml
```

Each subdirectory contains its own README with detailed playbook documentation.

## Prerequisites

```bash
# Install Ansible
pip install ansible

# Or on macOS
brew install ansible
```

## Configuration

1. Update the inventory file with your Proxmox host details:
   - Edit `inventory.ini`
   - Replace `192.168.100.50` with your Proxmox host IP
   - Update `ansible_user` if not using root

2. Ensure SSH access to your Proxmox host:
   ```bash
   # Copy your SSH key to the Proxmox host
   ssh-copy-id root@proxmox-host-ip
   ```

## Usage

### Quick Setup (Recommended)

Use the helper scripts from the project root:
```bash
# Complete K8s setup
./setup-k8s-complete.sh

# Setup monitoring
./run-monitoring-setup.sh
./run-monitoring-dashboards-setup.sh

# Setup database
./run-database-setup.sh

# Setup n8n automation
./run-n8n-setup.sh
```

### Manual Playbook Execution

All playbooks are now organized in subdirectories:

```bash
cd ansible

# Infrastructure
ansible-playbook playbooks/infrastructure/proxmox-setup.yml
ansible-playbook playbooks/infrastructure/qemu-agent-setup.yml
ansible-playbook playbooks/infrastructure/docker-setup.yml
ansible-playbook playbooks/infrastructure/nginx-gateway-setup.yml

# Kubernetes
ansible-playbook playbooks/kubernetes/k3s-cluster-setup.yml

# Services
ansible-playbook playbooks/services/database-setup.yml
ansible-playbook playbooks/services/monitoring-setup.yml
ansible-playbook playbooks/services/monitoring-dashboards-setup.yml
ansible-playbook playbooks/services/n8n-setup.yml
ansible-playbook playbooks/services/cicd-setup.yml

# Networking
ansible-playbook playbooks/networking/cloudflare-tunnel-setup.yml
ansible-playbook playbooks/networking/github-runner-setup.yml
```

### Run on Specific Hosts

```bash
# Install Docker only on monitoring VM
ansible-playbook playbooks/infrastructure/docker-setup.yml --limit monitoring

# Setup K3s only on workers
ansible-playbook playbooks/kubernetes/k3s-cluster-setup.yml --tags workers
```

### Test connectivity
```bash
# Test Proxmox host
ansible proxmox -m ping

# Test all VMs
ansible vms -m ping

# Test all hosts
ansible all -m ping
```

### Dry run (check mode)
```bash
ansible-playbook proxmox-setup.yml --check
```

## Playbooks

Playbooks are organized by category. See each subdirectory's README for detailed documentation:

### 🏗️ [Infrastructure](playbooks/infrastructure/)
Core infrastructure setup for Proxmox and VMs:
- **proxmox-setup.yml** - Configure Proxmox host with essential tools
- **qemu-agent-setup.yml** - Install QEMU Guest Agent on VMs
- **docker-setup.yml** - Install Docker CE on Ubuntu 24.04 VMs
- **nginx-gateway-setup.yml** - Install native Nginx on gateway VM

[→ View Infrastructure README](playbooks/infrastructure/README.md)

### ☸️ [Kubernetes](playbooks/kubernetes/)
Kubernetes cluster deployment:
- **k3s-cluster-setup.yml** - Deploy K3s cluster (1 master + 2 workers) with ingress-nginx

[→ View Kubernetes README](playbooks/kubernetes/README.md)

### 🚀 [Services](playbooks/services/)
Application services and infrastructure components:
- **database-setup.yml** - PostgreSQL, MySQL, MongoDB on dedicated VM
- **monitoring-setup.yml** - Prometheus + Grafana + Node Exporter
- **monitoring-dashboards-setup.yml** - Auto-provision 8 Grafana dashboards
- **n8n-setup.yml** - n8n workflow automation platform
- **cicd-setup.yml** - GitHub Actions runner + Docker registry

[→ View Services README](playbooks/services/README.md)

### 🌐 [Networking](playbooks/networking/)
Network configuration and remote access:
- **cloudflare-tunnel-setup.yml** - Cloudflare Tunnel for secure remote access
- **github-runner-setup.yml** - GitHub Actions runner (legacy/standalone)

[→ View Networking README](playbooks/networking/README.md)
Configures the Proxmox host with essential tools:
- Updates apt cache
- Installs fastfetch (modern system information tool, neofetch alternative)
- Installs htop (interactive process viewer)
- Installs additional monitoring tools (iotop, ncdu, tmux)
- Installs Speedtest CLI (network speed testing)
- Verifies installations

### cloudflare-tunnel-setup.yml
Sets up Cloudflare Tunnel on the Proxmox host:
- Adds Cloudflare repository and GPG key
- Installs cloudflared package
- Provides next steps for tunnel configuration

**Post-installation steps:**
```bash
# 1. Authenticate with Cloudflare
cloudflared tunnel login

# 2. Create a tunnel
cloudflared tunnel create homelab-ssh

# 3. Create config file
sudo nano /etc/cloudflared/config.yml

# 4. Route DNS
cloudflared tunnel route dns homelab-ssh ssh.yourdomain.com

# 5. Start as a service
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

### docker-setup.yml
Installs Docker CE on Ubuntu 24.04 VMs (excludes app-gateway for resource efficiency):
- Installs prerequisites (ca-certificates, curl, gnupg)
- Adds Docker's official GPG key and repository
- Installs Docker CE, CLI, containerd, buildx, and compose plugins
- Enables and starts Docker service
- Adds root user to docker group
- Verifies Docker installation

**Target VMs:** k8s-master, k8s-workers, monitoring, n8n, ci-cd

**Usage:**
```bash
# Install Docker on all VMs (except app-gateway)
ansible-playbook docker-setup.yml

# Install on specific VMs
ansible-playbook docker-setup.yml --limit monitoring,n8n

# Check mode (dry run)
ansible-playbook docker-setup.yml --check
```

### nginx-gateway-setup.yml
Installs native Nginx on app-gateway VM (lightweight, no Docker overhead):
- Installs Nginx from Ubuntu repositories
- Configures reverse proxy snippets
- Sets up default site with health check endpoint
- Creates directory structure for custom sites
- Enables and starts Nginx service

**Why native Nginx?** app-gateway has only 1GB RAM - Docker would consume 100-200MB unnecessarily.

**Usage:**
```bash
# Install Nginx on app-gateway
ansible-playbook nginx-gateway-setup.yml

# Test health check after installation
curl http://192.168.100.204/health

# Add reverse proxy configs in /etc/nginx/sites-available/
# Use 'include snippets/proxy-params.conf;' for proxy settings
```

### k3s-cluster-setup.yml
Sets up a complete K3s Kubernetes cluster (1 master + 2 workers):
- Installs K3s v1.28.8 on master node
- Retrieves cluster join token
- Joins worker nodes to the cluster
- Configures kubectl access for ubuntu user
- Fetches kubeconfig to local machine for remote access
- Disables Traefik (use your own ingress controller)
- Updates /etc/hosts on all nodes

**Features:**
- Lightweight K3s (perfect for homelab)
- 3-node cluster: k8s-master, k8s-worker-1, k8s-worker-2
- kubectl configured on master and local machine
- Ready for workload deployment

**Usage:**
```bash
# Setup entire cluster (runs sequentially)
ansible-playbook k3s-cluster-setup.yml

# Access from master node
ssh ubuntu@192.168.100.201
kubectl get nodes

# Access from local machine
export KUBECONFIG=~/Documents/ProgrammingProjects/homelab-journey/kubeconfig
kubectl get nodes
kubectl get pods -A

# Install kubectl locally if needed
brew install kubectl
```

**Post-installation:**
- Deploy ingress controller (Nginx/Traefik)
- Install cert-manager for TLS
- Deploy monitoring (Prometheus/Grafana)
- Configure persistent storage

### monitoring-setup.yml
Deploys complete monitoring stack (Prometheus + Grafana + Node Exporter) on dedicated monitoring VM:
- Installs Docker and docker-compose
- Deploys Prometheus v2.48.1 for metrics collection
- Deploys Grafana 10.2.3 for visualization
- Deploys Node Exporter for system metrics
- Pre-configures Prometheus scrape targets for all infrastructure
- Auto-provisions Grafana datasource
- Sets up 30-day metrics retention
- Configures persistent storage in `/opt/monitoring`

**Pre-configured monitoring targets:**
- Prometheus itself (localhost:9090)
- Node Exporter on monitoring VM
- All K8s nodes (192.168.100.201-203:9100)
- PostgreSQL on database-vm (192.168.100.205:9187)
- Docker Registry on ci-cd (192.168.100.240:5000)

**Usage:**
```bash
# Setup monitoring stack
ansible-playbook monitoring-setup.yml

# Or use the helper script (recommended)
cd ..
./run-monitoring-setup.sh
```

**Access:**
```bash
# Prometheus (Metrics & Alerts)
http://192.168.100.220:9090

# Grafana (Dashboards)
http://192.168.100.220:3000
# Default credentials: admin/admin (change on first login!)

# Check scrape targets
http://192.168.100.220:9090/targets
```

**Features:**
- **Prometheus**: Metrics database with 30-day retention
- **Grafana**: Visualization with auto-configured Prometheus datasource
- **Node Exporter**: System metrics (CPU, memory, disk, network)
- **Health checks**: Container health monitoring
- **Persistent storage**: Data survives container restarts
- **Ready for dashboards**: Use monitoring-dashboards-setup.yml

### monitoring-dashboards-setup.yml
Auto-provisions 8 production-ready Grafana dashboards:
- Downloads popular dashboards from grafana.com
- Automatically installs them in "Homelab" folder
- No manual dashboard configuration needed
- Includes dashboards for Node Exporter, Kubernetes, Docker, PostgreSQL

**Dashboards included:**
- Node Exporter Full (ID 1860) - Complete system metrics
- Node Exporter Dashboard (ID 11074) - System overview
- Prometheus 2.0 Overview (ID 3662)
- Kubernetes Cluster Monitoring (ID 7362)
- Kubernetes Nodes Monitoring (ID 15661)
- Docker Container Monitoring (ID 12708)
- Docker and System Monitoring (ID 893)
- PostgreSQL Database Dashboard (ID 9628)

**Prerequisites:**
- Monitoring stack must be running (run `monitoring-setup.yml` first)

**Usage:**
```bash
# Auto-provision all dashboards
ansible-playbook monitoring-dashboards-setup.yml

# Or use the helper script (recommended)
cd ..
./run-monitoring-dashboards-setup.sh
```

**Access dashboards:**
1. Open Grafana: http://192.168.100.220:3000
2. Login with admin/admin
3. Navigate to: Dashboards → Browse → Homelab folder
4. All 8 dashboards are ready to use!

**Technical details:**
- Uses Grafana provisioning API
- Downloads JSON from grafana.com/api/dashboards
- Automatically configures datasource mappings
- Dashboards are editable and persist across restarts

### cicd-setup.yml
Sets up comprehensive CI/CD environment on ci-cd VM:
- Installs GitHub Actions self-hosted runner (v2.314.1)
- Deploys private Docker Registry on port 5000
- Installs build tools (git, nodejs, python3, build-essential)
- Installs kubectl and helm for K8s deployments
- Creates runner user with Docker access
- Configures kubeconfig for deploying to K8s cluster

**Components:**
- **GitHub Runner**: Pre-downloaded, needs token configuration
- **Docker Registry**: Running at 192.168.100.240:5000
- **K8s Tools**: kubectl + helm for deployments

**Usage:**
```bash
# Setup CI/CD environment
ansible-playbook cicd-setup.yml

# Configure GitHub Actions runner
ssh ubuntu@192.168.100.240
sudo su - runner
cd actions-runner
./config.sh --url https://github.com/USERNAME/REPO --token YOUR_TOKEN --name homelab-runner
sudo ./svc.sh install runner
sudo ./svc.sh start

# Use Docker Registry
docker tag myapp:latest 192.168.100.240:5000/myapp:latest
docker push 192.168.100.240:5000/myapp:latest

# From K8s, pull images:
# image: 192.168.100.240:5000/myapp:latest
```

**Get GitHub token:**
1. Go to repo Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Copy the token from configuration command

**Runner capabilities:**
- Build and push Docker images
- Deploy to K8s cluster (kubectl configured)
- Install Helm charts
- Run any build command (npm, pip, make, etc.)

### database-setup.yml
Sets up centralized database server with PostgreSQL, MySQL, and MongoDB:
- Installs Docker CE for containerized databases
- Deploys PostgreSQL 16 on port 5432
- Deploys MySQL 8.0 on port 3306
- Deploys MongoDB 7.0 on port 27017
- Creates proper data directories and volumes
- Configures automated daily backups at 2 AM
- Sets up dedicated Docker network for databases
- Configures firewall rules for database access

**Why dedicated database VM?**
- Better performance with dedicated resources
- Easier backup and data management
- Persistent storage outside container orchestration
- One server hosts multiple databases for all projects
- Separates stateful from stateless workloads

**Usage:**
```bash
# Set secure passwords before running
export POSTGRES_PASSWORD=your_secure_password
export MYSQL_ROOT_PASSWORD=your_secure_password
export MONGO_ROOT_PASSWORD=your_secure_password

# Setup database server
ansible-playbook database-setup.yml

# Connect to databases
# PostgreSQL
psql -h 192.168.100.205 -U postgres -d database_name

# MySQL
mysql -h 192.168.100.205 -u root -p

# MongoDB
mongosh mongodb://admin:password@192.168.100.205:27017
```

**Features:**
- **PostgreSQL**: Alpine-based lightweight container
- **MySQL**: Official MySQL 8.0 image
- **MongoDB**: Official MongoDB 7.0 image
- **Backups**: Automated daily backups with 7-day retention
- **Health checks**: Container health monitoring
- **Network isolation**: Dedicated Docker network
- **Volumes**: Persistent data in `/opt/databases/`

**Manual backup:**
```bash
ssh ubuntu@192.168.100.205
sudo /opt/databases/backup.sh
```

**Connection strings for apps:**
```bash
# PostgreSQL
postgresql://postgres:password@192.168.100.205:5432/dbname

# MySQL
mysql://root:password@192.168.100.205:3306/dbname

# MongoDB
mongodb://admin:password@192.168.100.205:27017/dbname
```

### n8n-setup.yml
Sets up n8n workflow automation platform with PostgreSQL backend:
- Creates dedicated n8n database on database-vm
- Deploys n8n using Docker with PostgreSQL storage
- Configures webhooks and external access
- Sets up timezone and execution settings
- Enables workflow persistence and versioning
- Creates management scripts for easy operations

**What is n8n?**
n8n is a powerful workflow automation tool (self-hosted alternative to Zapier/Make). Perfect for:
- CI/CD pipeline automation
- Database backup scheduling
- Monitoring alert routing
- Infrastructure automation
- API integrations
- Data synchronization

**Prerequisites:**
- Docker installed on n8n VM
- PostgreSQL running on database-vm (run `database-setup.yml` first)

**Important:** Before running, edit `ansible/n8n-setup.yml` to set:
1. Secure database password (`n8n_db_password`)
2. Encryption key (`n8n_encryption_key`) - Generate with: `openssl rand -hex 16`
3. Your timezone (optional)
4. Webhook URL (optional, for production use)

**Usage:**
```bash
# Generate a secure encryption key
openssl rand -hex 16

# Edit the playbook with your secure passwords
nano ansible/n8n-setup.yml

# Run the setup
ansible-playbook n8n-setup.yml

# Or use the helper script (recommended)
cd ..
./run-n8n-setup.sh
```

**Access n8n:**
```bash
# Web Interface
http://192.168.100.230:5678

# First-time setup:
# 1. Create your owner account (first user to register becomes owner)
# 2. Start building workflows!
```

**Management commands (on n8n VM):**
```bash
# SSH to n8n VM
ssh -i ssh-keys/vm-key ubuntu@192.168.100.230

# Convenient commands
n8n-start    # Start n8n
n8n-stop     # Stop n8n
n8n-restart  # Restart n8n
n8n-logs     # View logs (follow mode)
n8n-status   # Check container status and health

# Manual control
cd /opt/n8n
docker-compose up -d    # Start
docker-compose down     # Stop
docker-compose restart  # Restart
docker logs -f n8n      # View logs
```

**Configuration:**
- **Installation directory:** `/opt/n8n/`
- **Workflows & credentials:** `/opt/n8n/.n8n/`
- **Database:** PostgreSQL on 192.168.100.205 (database: n8n)
- **Port:** 5678
- **Resources:** 2 CPU, 6GB RAM, 50GB disk

**Security recommendations:**
- ✅ Change default passwords before deployment
- ✅ Use strong encryption key (32+ chars)
- ✅ Consider enabling N8N_BASIC_AUTH for additional security
- ✅ Set up reverse proxy with SSL for production
- ✅ Configure webhooks to use your domain name
- ✅ Regularly backup `/opt/n8n/.n8n/` directory

**Optional features to enable:**
```yaml
# In docker-compose.yml environment section:
- N8N_BASIC_AUTH_ACTIVE=true
- N8N_BASIC_AUTH_USER=admin
- N8N_BASIC_AUTH_PASSWORD=changeme
- N8N_METRICS=true  # Enable Prometheus metrics
```

## Inventory Structure

- `[proxmox]` - Proxmox host (192.168.100.50)
- `[vms]` - All VM instances
- `[app-gateway]` - Reverse proxy VM (nginx, 1C/2GB)
- `[k8s]` - Kubernetes cluster nodes (master + workers)
- `[database]` - Database server VM (PostgreSQL, MySQL, MongoDB, 4C/8GB)
- `[ci-cd]` - CI/CD VM (GitHub/GitLab runners, Docker registry)
- Groups can be combined: `vms:!app-gateway` excludes gateway from operations

## Next Steps

Completed playbooks:
- ✅ K3s Kubernetes cluster with ingress-nginx
- ✅ Monitoring stack (Prometheus + Grafana with auto-provisioned dashboards)
- ✅ Database server (PostgreSQL, MySQL, MongoDB)
- ✅ n8n workflow automation
- ✅ CI/CD environment (GitHub Actions runner + Docker registry)
- ✅ Docker installation across VMs
- ✅ Nginx gateway

Additional playbooks to consider:
- Certificate management (cert-manager + Let's Encrypt)
- ArgoCD deployment (GitOps for K8s)
- Persistent storage configuration (Longhorn/NFS/Rook-Ceph)
- Backup configuration (Velero for K8s, Restic for VMs)
- Log aggregation (Loki + Promtail)
- Service mesh (Istio/Linkerd)
- Secrets management (Vault/External Secrets Operator)
