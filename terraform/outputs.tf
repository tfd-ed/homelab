output "vm_ips" {
  description = "IP addresses of all VMs"
  value = {
    for vm_name, vm_config in var.vms : vm_name => vm_config.ip_address
  }
}

output "vm_ids" {
  description = "Proxmox VM IDs"
  value = {
    for vm_name, vm in proxmox_virtual_environment_vm.vms : vm_name => vm.vm_id
  }
}

output "vm_summary" {
  description = "Summary of all VMs"
  value = {
    for vm_name, vm in proxmox_virtual_environment_vm.vms : vm_name => {
      id          = vm.vm_id
      ip          = var.vms[vm_name].ip_address
      cores       = var.vms[vm_name].cores
      memory_mb   = var.vms[vm_name].memory
      disk_size   = var.vms[vm_name].disk_size
      description = var.vms[vm_name].description
    }
  }
}
