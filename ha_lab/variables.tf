variable "pm_api_url" {
  description = "Proxmox API URL, e.g. https://<proxmox-host>:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID, e.g. root@pam!terraform"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification (self-signed Proxmox certs)"
  type        = bool
  default     = true
}

variable "vm_cores" {
  description = "vCPU cores per node"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory per node in MB"
  type        = number
  default     = 2048
}

variable "vm_disk_size" {
  description = "Boot disk size; must be >= the template's disk size"
  type        = string
  default     = "20G"
}

variable "vm_storage" {
  description = "Proxmox storage for the boot and cloud-init disks"
  type        = string
  default     = "local-lvm"
}
