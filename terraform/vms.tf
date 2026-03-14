# Download Ubuntu Cloud Image
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud-images.ubuntu.com/noble/20260225/noble-server-cloudimg-amd64.img"
  # need to rename the file to *.qcow2 to indicate the actual file format for import
  file_name = "noble-server-cloudimg-amd64.qcow2"
}

# Create VMs
resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vms

  name        = each.key
  node_name   = var.target_node
  description = each.value.description
  
  on_boot = true
  vm_id   = null  # Auto-assign VM ID
  
  agent {
    enabled = true
  }
  
  cpu {
    cores = each.value.cores
    type  = "host"
  }
  
  memory {
    dedicated = each.value.memory
  }
  
  disk {
    datastore_id = var.storage_pool
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = tonumber(regex("^([0-9]+)", each.value.disk_size)[0])
  }
  
  network_device {
    bridge      = var.network_bridge
    vlan_id     = var.vlan_tag == -1 ? null : var.vlan_tag
  }
  
  initialization {
    user_data_file_id = "local:snippets/cloud-init-user-data.yml"
    
    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
        gateway = var.gateway
      }
    }
    
    dns {
      servers = [var.nameserver]
    }
  }
  
  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}
