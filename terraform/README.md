# Terraform - Proxmox VM Provisioning

This directory contains Terraform configuration to provision all 8 VMs for the homelab on Proxmox using the `bpg/proxmox` provider.

## 📋 Table of Contents

- [Overview](#-overview)
- [VMs Provisioned](#vms-provisioned)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Network Configuration](#network-configuration)
- [SSH Access](#ssh-access)
- [Customization](#customization)
- [Next Steps](#next-steps)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Related Documentation](#related-documentation)

## 📋 Overview

This Terraform configuration automates the creation of a complete homelab infrastructure on Proxmox VE. It provisions virtual machines with cloud-init, configures networking, and sets up SSH access - providing a reproducible Infrastructure as Code (IaC) foundation.

**Key Features:**
- ✅ Automated VM provisioning with Ubuntu 22.04 cloud image
- ✅ Cloud-init configuration for initial setup
- ✅ SSH key injection for passwordless access
- ✅ Static IP configuration
- ✅ Idempotent deployments (safe to re-run)

## VMs Provisioned

| VM Name | vCPU | RAM | Disk | IP Address | Purpose |
|---------|------|-----|------|------------|---------|
| k8s-master | 2 | 4GB | 50GB | 192.168.100.201 | Kubernetes control plane (K3s) |
| k8s-worker-1 | 4 | 14GB | 150GB | 192.168.100.202 | Kubernetes worker node |
| k8s-worker-2 | 4 | 14GB | 150GB | 192.168.100.203 | Kubernetes worker node |
| **database-vm** | **4** | **6GB** | **200GB** | **192.168.100.205** | **PostgreSQL + MySQL + MongoDB** |
| app-gateway | 1 | 2GB | 20GB | 192.168.100.210 | Nginx reverse proxy |
| monitoring | 2 | 6GB | 80GB | 192.168.100.220 | Prometheus + Grafana + Loki |
| n8n | 2 | 6GB | 50GB | 192.168.100.230 | n8n workflow automation |
| ci-cd | 2 | 5GB | 100GB | 192.168.100.240 | GitHub Actions + Docker registry |

**Total Resources:** 21 vCPUs, 57GB RAM, 820GB storage

> 💡 **See Also:** [Main README - Infrastructure Overview](../README.md#%EF%B8%8F-infrastructure-overview) for detailed VM descriptions and resource allocation notes.

## Prerequisites

### 1. Install Terraform

```bash
# macOS
brew install terraform

# Or download from https://www.terraform.io/downloads
```

### 2. Proxmox Preparation

**No manual template creation required!** The Terraform configuration automatically downloads the Ubuntu cloud image to your Proxmox `local` storage.

Ensure you have:
- Proxmox VE 7.0 or later
- `local` storage for ISO images
- `local-lvm` (or your preferred storage) for VM disks
- Network configured (default: vmbr0)
- **SSH access enabled** on Proxmox (the provider needs SSH to import disk images)
  - If using non-standard SSH port, update in `provider.tf`
  - Default configuration uses port 1308 (update if different)

**Resource Requirements:**
- **Minimum Host Resources:** 24 CPU cores, 64GB RAM, 1TB storage
- **VMs will use:** 21 vCPUs, 57GB RAM, 820GB storage
- **Recommended:** Leave headroom for Proxmox host (typically 10-20%)

> 💡 **Tip:** See [hardware.md](../hardware.md) for the reference hardware configuration running this infrastructure.

### 3. Create Proxmox API Token (Recommended)

In Proxmox Web UI:
1. Go to **Datacenter → Permissions → API Tokens**
2. Create a new token for your user
3. Save the token ID and secret

Or use password authentication.

### 4. Configure Terraform Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
nano terraform.tfvars
```

**Required variables:**
- `proxmox_password` - Your Proxmox root password
- `ssh_public_key` - Your SSH public key (from `~/.ssh/id_rsa.pub`)

**Optional variables to customize:**
- `proxmox_api_url` - Default: https://192.168.100.50:8006/
- VM IP addresses - Adjust in `variables.tf` if needed
- Network settings (gateway, nameserver)

## Usage

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Plan Deployment

```bash
# Preview what will be created
terraform plan
```

### Deploy All VMs

```bash
# Create all 7 VMs
terraform apply

# Auto-approve (skip confirmation)
terraform apply -auto-approve
```

### Deploy Specific VMs

```bash
# Deploy only specific VMs
terraform apply -target=proxmox_vm_qemu.vms[\"k8s-master\"]
terraform apply -target=proxmox_vm_qemu.vms[\"app-gateway\"]
```

### View Outputs

```bash
# Show VM IPs and IDs
terraform output

# Show specific output
terraform output vm_ips
terraform output vm_summary
```

### Destroy VMs

```bash
# Destroy all VMs
terraform destroy

# Destroy specific VM
terraform destroy -target=proxmox_vm_qemu.vms[\"k8s-master\"]
```

## Network Configuration

Default IP scheme (192.168.100.x/24):
- **Proxmox Host**: 192.168.100.50
- **Gateway**: 192.168.100.1
- **DNS**: 8.8.8.8
- **K8s Cluster**: 192.168.100.201-203
- **Database Server**: 192.168.100.205
- **App Gateway**: 192.168.100.210
- **Services**: 192.168.100.220-240 (monitoring, n8n, ci-cd)

Modify in `variables.tf` if your network is different.

> 💡 **See Also:** [Main README - Network Topology](../README.md#%EF%B8%8F-network-topology) for the complete network diagram.

## SSH Access

After VMs are created:

```bash
# SSH to VMs (using configured user, default: ubuntu)
ssh ubuntu@192.168.100.201  # k8s-master
ssh ubuntu@192.168.100.202  # k8s-worker-1
ssh ubuntu@192.168.100.203  # k8s-worker-2
ssh ubuntu@192.168.100.205  # database-vm
ssh ubuntu@192.168.100.210  # app-gateway
ssh ubuntu@192.168.100.220  # monitoring
ssh ubuntu@192.168.100.230  # n8n
ssh ubuntu@192.168.100.240  # ci-cd
```

**Configure SSH aliases for convenience:**

```bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host k8s-master
    HostName 192.168.100.201
    User ubuntu
    IdentityFile ~/.ssh/id_rsa

Host k8s-worker-1
    HostName 192.168.100.202
    User ubuntu
    IdentityFile ~/.ssh/id_rsa

Host k8s-worker-2
    HostName 192.168.100.203
    User ubuntu
    IdentityFile ~/.ssh/id_rsa

Host database-vm
    HostName 192.168.100.205
    User ubuntu
    IdentityFile ~/.ssh/id_rsa

# ... add more as needed
EOF

# Then connect simply with:
ssh k8s-master
ssh database-vm
```

> 💡 **See Also:** [SSH Setup Guide](./SSH_SETUP.md) for advanced SSH configuration, key management, and security best practices.

## Customization

### Modify VM Resources

Edit `variables.tf` → `vms` variable:

```hcl
vms = {
  k8s-master = {
    cores       = 4        # Increase from 2 to 4
    memory      = 8192     # Increase from 4GB to 8GB
    disk_size   = "100G"   # Increase from 50GB to 100GB
    ip_address  = "192.168.100.201"
    description = "Kubernetes Master"
  }
  
  database-vm = {
    cores       = 8        # Increase for heavier database workload
    memory      = 16384    # Increase from 6GB to 16GB
    disk_size   = "500G"   # Increase for more data storage
    ip_address  = "192.168.100.205"
    description = "Database Server"
  }
}
```

### Add More VMs

Add to the `vms` map in `variables.tf`:

```hcl
my-custom-vm = {
  cores       = 2
  memory      = 4096
  disk_size   = "50G"
  ip_address  = "192.168.100.250"
  description = "Custom application server"
}
```

Then run `terraform apply` - Terraform will only create the new VM.

## Next Steps

After provisioning VMs with Terraform, continue with configuration management:

### 1. Verify VM Access

```bash
# Test SSH access to all VMs
ssh ubuntu@192.168.100.201  # k8s-master
ssh ubuntu@192.168.100.202  # k8s-worker-1
ssh ubuntu@192.168.100.203  # k8s-worker-2
ssh ubuntu@192.168.100.205  # database-vm
ssh ubuntu@192.168.100.210  # app-gateway
ssh ubuntu@192.168.100.220  # monitoring
ssh ubuntu@192.168.100.230  # n8n
ssh ubuntu@192.168.100.240  # ci-cd
```

### 2. Continue with Ansible Configuration

Once VMs are provisioned, use Ansible to configure them:

```bash
cd ../ansible

# Update inventory.ini with your VMs (if not already configured)

# Run complete setup
cd ..
./setup-k8s-complete.sh

# Or configure services individually
cd ansible
ansible-playbook playbooks/kubernetes/k3s-cluster-setup.yml
ansible-playbook playbooks/services/database-setup.yml
ansible-playbook playbooks/services/monitoring-setup.yml
# ... etc
```

**See:** 
- [Main README - Quick Start](../README.md#-quick-start) for automated setup
- [Main README - Complete Setup Guide](../README.md#-complete-setup-guide) for step-by-step instructions
- [Ansible README](../ansible/README.md) for configuration management details

### 3. Verify Infrastructure

```bash
# Check all VMs are running in Proxmox
# Web UI: https://192.168.100.50:8006

# Or via shell
terraform output vm_summary
```

## Troubleshooting

### Error: unable to authenticate user "root" over SSH

The provider needs SSH access to import disk images. Check:
- SSH is enabled and accessible on your Proxmox host
- SSH port is correct in `provider.tf` (currently set to 1308)
- Root user can SSH with password authentication
- Test manually: `ssh -p 1308 root@192.168.100.50`

If using a different SSH port, update in `provider.tf`:
```hcl
ssh {
  port = 22  # Change to your SSH port
}
```

### Error: Failed to connect to Proxmox

- Check `proxmox_api_url` is correct (should end with `/`)
- Verify Proxmox is accessible: `curl -k https://192.168.100.50:8006`
- Check credentials are correct

### Error: Image download failed

- Ensure `local` storage exists and has space
- Check internet connectivity from Proxmox host
- Verify URL is accessible: Ubuntu cloud images may change

### VMs not getting IP addresses

- Wait for cloud-init to complete (~1-2 minutes after first boot)
- Check DHCP/network settings match your environment
- Verify gateway and DNS settings are correct

### SSH connection refused

- Wait for cloud-init to complete (~1-2 minutes)
- Check VM console in Proxmox web UI
- Verify SSH public key is correct
- Ensure qemu-guest-agent is running (automatically installed)

## Best Practices

1. **Use API tokens** instead of passwords for better security
2. **Keep `terraform.tfvars` out of git** (use `.gitignore`)
3. **Use remote state** for team collaboration (S3, Terraform Cloud)
4. **Tag VMs** with environment/purpose labels
5. **Backup state file** regularly (`terraform.tfstate`)
6. **Document changes** - commit infrastructure changes to Git
7. **Test in stages** - use `-target` flag to deploy incrementally
8. **Validate first** - always run `terraform plan` before `apply`

## Related Documentation

- **[Main README](../README.md)** - Complete homelab documentation
  - [Hardware Specifications](../README.md#-hardware-specifications)
  - [Infrastructure Overview](../README.md#%EF%B8%8F-infrastructure-overview)
  - [Quick Start Guide](../README.md#-quick-start)
  - [Complete Setup Guide](../README.md#-complete-setup-guide)
- **[Ansible Playbooks](../ansible/README.md)** - Configuration management after VM provisioning
- **[SSH Setup Guide](./SSH_SETUP.md)** - Advanced SSH configuration
- **[Kubernetes Management](../k8s/README.md)** - K8s deployment patterns

## Project Structure

```
terraform/
├── README.md              # This file
├── provider.tf            # Proxmox provider configuration
├── variables.tf           # Variable definitions
├── vms.tf                 # VM resource definitions
├── outputs.tf             # Output values (IPs, IDs)
├── terraform.tfvars       # Your values (gitignored)
├── terraform.tfvars.example  # Example configuration
├── terraform.tfstate      # State file (gitignored)
└── SSH_SETUP.md          # SSH configuration guide
```

---

**Terraform Version:** >= 1.5.0  
**Provider:** `bpg/proxmox` >= 0.40.0  
**Last Updated:** March 2026

## References

- [BPG Proxmox Provider Documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [Proxmox Cloud-Init Guide](https://pve.proxmox.com/wiki/Cloud-Init_Support)
