terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.10"
    }
  }
}


provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}


resource "proxmox_vm_qemu" "resource-name" {
  name        = "dev-machine"
  target_node = "proxmox"
  iso         = "local:iso/debian-11.2.0-amd64-netinst.iso"
  memory      = 8192
  cores       = 3
  sockets     = 1
  os_type     = "ubuntu"
  bios        = "seabios"
  cpu         = "host"
  kvm         = true

  network {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
  }

  disk {
    storage = "plex"
    size    = "32G"
    type    = "scsi"
    cache   = "writeback"
  }
}
