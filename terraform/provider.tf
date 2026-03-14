terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.60"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = var.proxmox_tls_insecure
  ssh  {
    agent = true
    private_key = file("~/homelab/keys/homelab_id_ed25519")
    node  {
        name = var.proxmox_node
        address = "192.168.100.50"
        port = var.proxmox_ssh_port
    }
  }
}
