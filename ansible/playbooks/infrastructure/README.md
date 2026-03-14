# Infrastructure Playbooks

Core infrastructure setup and configuration for Proxmox host and VMs.

## Playbooks

### proxmox-setup.yml
**Purpose:** Configure Proxmox host with essential tools and utilities  
**Target:** Proxmox host (192.168.100.50)  
**Usage:** `ansible-playbook playbooks/infrastructure/proxmox-setup.yml`

**Installs:**
- System information tools (fastfetch)
- Monitoring utilities (htop, iotop, ncdu)
- Terminal multiplexer (tmux)
- Speedtest CLI

### qemu-agent-setup.yml
**Purpose:** Install QEMU Guest Agent on VMs for better Proxmox integration  
**Target:** All VMs  
**Usage:** `ansible-playbook playbooks/infrastructure/qemu-agent-setup.yml`

**Benefits:**
- Better VM shutdown/restart handling
- Accurate metrics reporting to Proxmox
- Snapshot support with filesystem quiescing

### docker-setup.yml
**Purpose:** Install Docker CE on Ubuntu 24.04 VMs  
**Target:** VMs requiring Docker (excludes app-gateway)  
**Usage:** `ansible-playbook playbooks/infrastructure/docker-setup.yml`

**Installs:**
- Docker CE and CLI
- Docker Compose V2
- Container runtime (containerd)
- Docker Buildx

**Note:** app-gateway uses native Nginx (no Docker) for resource efficiency.

### nginx-gateway-setup.yml
**Purpose:** Install native Nginx on gateway VM  
**Target:** gateway-vm (192.168.100.210)  
**Usage:** `ansible-playbook playbooks/infrastructure/nginx-gateway-setup.yml`

**Configures:**
- Nginx from Ubuntu repositories (lightweight)
- Reverse proxy configuration snippets
- Default health check endpoint
- Site directory structure

**Why native Nginx?** Gateway VM has only 2GB RAM - Docker overhead (~200MB) is wasteful.

## Execution Order

For initial setup:
1. `proxmox-setup.yml` - Configure Proxmox host
2. `qemu-agent-setup.yml` - Install guest agent on all VMs
3. `docker-setup.yml` - Install Docker on required VMs
4. `nginx-gateway-setup.yml` - Configure gateway VM

## Related Documentation

- [Main Ansible README](../../README.md)
- [Inventory Configuration](../../inventory.ini)
