terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}



provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

variable "vm_base_config" {
  default = {
    image_storage = "local"      # Adjust according to your Proxmox setup
    image_file    = "ubuntu-22.04-template" # Ensure this image is available on Proxmox
    network       = "vmbr0"
    cores         = 2
    memory        = 2048             # 2GB RAM
    disk_size     = "20G"            # 20GB Disk
  }
}

variable "vm_names" {
  default = [
    "k8s-controller",
    "k8s-worker1",
    "k8s-worker2",
    "k8s-worker3"
  ]
}

resource "proxmox_vm_qemu" "k8s_nodes" {
  count       = 4
  name        = var.vm_names[count.index]
  target_node = "pve"  # Replace with your Proxmox node

  network {
    id      = 0
    model   = "virtio"
    bridge  = var.vm_base_config.network
  }

  disk {
    slot    = "scsi0"  # Replace with a valid disk slot identifier
    size    = var.vm_base_config.disk_size
    storage = var.vm_base_config.image_storage
  }

  cores   = var.vm_base_config.cores
  memory  = var.vm_base_config.memory
  onboot  = true
  agent   = 1 # Enables QEMU Guest Agent
}

output "vm_names" {
  value = [
    for vm in proxmox_vm_qemu.k8s_nodes: vm.name
  ]
}

