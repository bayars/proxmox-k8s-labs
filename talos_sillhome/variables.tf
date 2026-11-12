variable "pm_endpoint" {
  description = "Proxmox API endpoint, e.g. https://10.0.0.X:8006/"
  type        = string
}

variable "pm_token_id" {
  description = "API token id, e.g. root@pam!home-search"
  type        = string
  sensitive   = true
}

variable "pm_token_secret" {
  description = "API token secret (UUID)"
  type        = string
  sensitive   = true
}

variable "node_name" {
  description = "PVE node to create everything on; empty = first node reported by the cluster"
  type        = string
  default     = ""
}

variable "template_vm_id" {
  description = "VMID of the imported Talos nocloud-amd64 qcow2 template"
  type        = number
}

variable "datastore" {
  description = "Storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "bridge_name" {
  type    = string
  default = "vmbr1"
}

variable "bridge_cidr" {
  description = "Host-side gateway IP on the new bridge, e.g. 10.10.10.1/24"
  type        = string
  default     = "10.10.10.1/24"
}

variable "vm_subnet" {
  description = "Private subnet for the cluster VMs"
  type        = string
  default     = "10.10.10.0/24"
}

variable "vm_ip_first" {
  description = "First VM IP (CP first, then workers)"
  type        = string
  default     = "10.10.10.50"
}

variable "vm_dns" {
  description = "DNS servers for the VMs"
  type        = list(string)
  default     = ["1.1.1.1", "10.10.10.1"]
}

variable "cp_count" {
  type    = number
  default = 1
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "cp_cpu" {
  type    = number
  default = 2
}

variable "cp_mem_mb" {
  type    = number
  default = 4096
}

variable "cp_disk_gb" {
  type    = number
  default = 20
}

variable "worker_cpu" {
  type    = number
  default = 2
}

variable "worker_mem_mb" {
  type    = number
  default = 4096
}

variable "worker_disk_gb" {
  type    = number
  default = 30
}
