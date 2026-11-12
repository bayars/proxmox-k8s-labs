# sillhome Talos k8s cluster on Proxmox (API-token only, bpg provider)
terraform {
  required_version = ">= 1.6"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.120.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_endpoint
  api_token = "${var.pm_token_id}=${var.pm_token_secret}"
  insecure  = true # self-signed PVE cert
}
