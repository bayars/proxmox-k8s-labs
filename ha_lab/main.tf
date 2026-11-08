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

variable "template" {
  default = "k8s-node"
}

variable "network_config" {
  default = [
    { name = "controller-1", ip = "10.0.0.101", gw = "10.0.0.1" },
    { name = "controller-2", ip = "10.0.0.102", gw = "10.0.0.1" },
    { name = "controller-3", ip = "10.0.0.103", gw = "10.0.0.1" },
    { name = "worker-1",     ip = "10.0.0.104", gw = "10.0.0.1" }
  ]
}

resource "proxmox_vm_qemu" "nodes" {
  count            = length(var.network_config)
  name             = var.network_config[count.index].name
  target_node      = "pve" # Change to your Proxmox node
  clone            = var.template
  full_clone       = true

  /* cpu { */
  /*   cores = 2 */
  /* } */

  /* memory { */
  /*   dedicated = 2048 */
  /* } */

  /* disk { */
  /*   size = "20G" */
  /* } */

  /* network { */
  /*   model  = "virtio" */
  /*   bridge = "vmbr0" */
  /* } */

  /* cloudinit { */
  /*   ipconfig0 = "ip=${var.network_config[count.index].ip}/24,gw=${var.network_config[count.index].gw}" */
  /*   hostname  = var.network_config[count.index].name */
  /* } */

  lifecycle {
    ignore_changes = [network]
  }
}

