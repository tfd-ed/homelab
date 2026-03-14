# Proxmox Connection
variable "proxmox_api_url" {
  description = "Proxmox API URL (endpoint)"
  type        = string
  default     = "https://192.168.100.50:8006/"
}

variable "proxmox_user" {
  description = "Proxmox API user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_ssh_port" {
  description = "SSH port for Proxmox host"
  type        = number
  default     = 1308
}

# Proxmox Node
variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "target_node" {
  description = "Target node for VM deployment"
  type        = string
  default     = "pve"
}

# Storage
variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# Network
variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN tag (optional)"
  type        = number
  default     = -1
}

# VM Configurations
variable "vms" {
  description = "VM configurations"
  type = map(object({
    cores  = number
    memory = number
    disk_size = string
    ip_address = string
    description = string
  }))
  
  default = {
    k8s-master = {
      cores       = 2
      memory      = 4096
      disk_size   = "50G"
      ip_address  = "192.168.100.201"
      description = "Kubernetes Master - API server, scheduler, controller"
    }
    k8s-worker-1 = {
      cores       = 4
      memory      = 14336
      disk_size   = "150G"
      ip_address  = "192.168.100.202"
      description = "Kubernetes Worker 1 - Runs apps/containers"
    }
    k8s-worker-2 = {
      cores       = 4
      memory      = 14336
      disk_size   = "150G"
      ip_address  = "192.168.100.203"
      description = "Kubernetes Worker 2 - Runs apps/containers"
    }
    database-vm = {
      cores       = 4
      memory      = 6144
      disk_size   = "200G"
      ip_address  = "192.168.100.205"
      description = "Database Server - PostgreSQL, MySQL, MongoDB"
    }
    app-gateway = {
      cores       = 2
      memory      = 2048
      disk_size   = "20G"
      ip_address  = "192.168.100.210"
      description = "App Gateway - Nginx Proxy Manager reverse proxy"
    }
    monitoring = {
      cores       = 2
      memory      = 6144
      disk_size   = "80G"
      ip_address  = "192.168.100.220"
      description = "Monitoring - Prometheus, Grafana, Loki"
    }
    n8n = {
      cores       = 2
      memory      = 6144
      disk_size   = "50G"
      ip_address  = "192.168.100.230"
      description = "n8n Automation - Workflows and automation"
    }
    ci-cd = {
      cores       = 2
      memory      = 5120
      disk_size   = "100G"
      ip_address  = "192.168.100.240"
      description = "CI/CD - GitHub/GitLab runner"
    }
  }
}

# SSH Configuration
variable "ssh_user" {
  description = "SSH user for cloud-init"
  type        = string
  default     = "root"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.100.1"
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "8.8.8.8"
}
