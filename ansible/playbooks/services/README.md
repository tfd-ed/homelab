# Services Playbooks

Application services, databases, monitoring, and CI/CD pipeline setup.

## Playbooks

### database-setup.yml
**Purpose:** Deploy centralized database server with PostgreSQL, MySQL, MongoDB  
**Target:** database-vm (192.168.100.205)  
**Usage:** `ansible-playbook playbooks/services/database-setup.yml`

**Deploys:**
- PostgreSQL 16 (port 5432)
- MySQL 8.0 (port 3306)
- MongoDB 7.0 (port 27017)
- Automated daily backups (2 AM)
- 7-day backup retention

**Helper script:** `../../run-database-setup.sh`

---

### monitoring-setup.yml
**Purpose:** Deploy Prometheus, Grafana, and Node Exporter  
**Target:** monitoring (192.168.100.220)  
**Usage:** `ansible-playbook playbooks/services/monitoring-setup.yml`

**Deploys:**
- Prometheus v2.48.1 (port 9090)
- Grafana 10.2.3 (port 3000)
- Node Exporter (system metrics)
- 30-day metrics retention
- Pre-configured scrape targets

**Access:**
- Prometheus: http://192.168.100.220:9090
- Grafana: http://192.168.100.220:3000 (admin/admin)

**Helper script:** `../../run-monitoring-setup.sh`

---

### monitoring-dashboards-setup.yml
**Purpose:** Auto-provision 8 Grafana dashboards  
**Target:** monitoring (192.168.100.220)  
**Usage:** `ansible-playbook playbooks/services/monitoring-dashboards-setup.yml`

**Dashboards installed:**
- Node Exporter Full (1860)
- Kubernetes Cluster Monitoring (7362)
- Docker Container Monitoring (12708)
- PostgreSQL Database (9628)
- And 4 more...

**Pre-requisite:** monitoring-setup.yml must be run first

**Helper script:** `../../run-monitoring-dashboards-setup.sh`

---

### n8n-setup.yml
**Purpose:** Deploy n8n workflow automation platform  
**Target:** n8n (192.168.100.230) + database-vm  
**Usage:** `ansible-playbook playbooks/services/n8n-setup.yml`

**Deploys:**
- n8n (latest) with PostgreSQL backend
- Dedicated database on database-vm
- Webhook configuration
- Management scripts

**Access:** http://192.168.100.230:5678

**IMPORTANT:** Edit playbook to set secure passwords before running!
```bash
# Generate encryption key
openssl rand -hex 16

# Edit passwords (lines 9 and 74)
nano playbooks/services/n8n-setup.yml
```

**Helper script:** `../../run-n8n-setup.sh`

---

### cicd-setup.yml
**Purpose:** Setup CI/CD environment with GitHub Actions runner and Docker registry  
**Target:** ci-cd (192.168.100.240)  
**Usage:** `ansible-playbook playbooks/services/cicd-setup.yml`

**Installs:**
- GitHub Actions self-hosted runner
- Docker Registry (port 5000)
- Nginx reverse proxy for registry
- kubectl and helm
- Build tools (git, nodejs, python3)

**Registry access:**
- Direct: `192.168.100.240:5000`
- Hostname: `registry.homelab.local` (no port)

**Post-installation:** Configure GitHub runner token
```bash
ssh ubuntu@192.168.100.240
sudo su - runner
cd actions-runner
./config.sh --url https://github.com/USER/REPO --token TOKEN
```

## Execution Order

Recommended setup sequence:

1. **Database** - `database-setup.yml` (used by n8n)
2. **Monitoring** - `monitoring-setup.yml` (observability first)
3. **Dashboards** - `monitoring-dashboards-setup.yml` (visualization)
4. **n8n** - `n8n-setup.yml` (automation platform)
5. **CI/CD** - `cicd-setup.yml` (deployment pipeline)

## Pre-requisites

All services require:
- ✅ VMs provisioned and accessible
- ✅ Docker installed (`playbooks/infrastructure/docker-setup.yml`)
- ✅ K8s cluster running (for CI/CD deployments)

## Helper Scripts

All services have helper scripts in project root:
```bash
./run-database-setup.sh
./run-monitoring-setup.sh
./run-monitoring-dashboards-setup.sh
./run-n8n-setup.sh
```

## Documentation

- [Quick Reference](../../../QUICK_REFERENCE.md)
- [Main README](../../../README.md)
