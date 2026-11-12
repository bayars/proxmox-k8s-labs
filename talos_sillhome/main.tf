# Cluster layout:
#   vmbr2           new private bridge, host holds the gateway IP (10.10.10.1/24)
#   NAT/SNAT        datacenter firewall rule added after apply (raw API call, see README)
#   VMs             cloned from the Talos nocloud template; static IPs delivered through
#                   the cloud-init (NoCloud) drive, which the Talos nocloud platform reads.
#                   Each VM gets its own network-config snippet (uploaded via API).

data "proxmox_virtual_environment_nodes" "all" {}

locals {
  node = var.node_name != "" ? var.node_name : data.proxmox_virtual_environment_nodes.all.names[0]

  vm_specs = concat(
    [for i in range(var.cp_count) : {
      role    = "cp"
      name    = "sill-cp${i + 1}"
      ip      = cidrhost(var.vm_subnet, 50 + i)
      cpu     = var.cp_cpu
      mem     = var.cp_mem_mb
      disk_gb = var.cp_disk_gb
    }],
    [for i in range(var.worker_count) : {
      role    = "worker"
      name    = "sill-w${i + 1}"
      ip      = cidrhost(var.vm_subnet, 50 + var.cp_count + i)
      cpu     = var.worker_cpu
      mem     = var.worker_mem_mb
      disk_gb = var.worker_disk_gb
    }]
  )
}

# --- private bridge for the cluster -------------------------------------------
# vmbr2 (10.10.10.1/24, no ports) is created out-of-band: the provider cannot read
# bridges back with a scoped token, so tofu references it by name only.

# --- VMs ----------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "talos" {
  for_each = { for s in local.vm_specs : s.name => s }

  name        = each.key
  node_name   = local.node
  description = "sillhome talos ${each.value.role} (tofu)"
  tags        = ["talos", "sillhome", each.value.role]
  on_boot     = true
  started     = contains(var.start_vms, each.key)
  stop_on_destroy = true

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.mem
  }

  disk {
    datastore_id = var.datastore
    interface    = "ide0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge = var.bridge_name
    model  = "virtio"
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "other" # talos
  }

  # NoCloud seed drive (ide2): static network config for the Talos nocloud platform
  # Proxmox-generated cloud-init drive (API only, no snippet upload / SSH needed).
  # Talos' nocloud platform reads the static network config from it.
  initialization {
    datastore_id = var.datastore
    dns {
      servers = var.vm_dns
    }
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = cidrhost(var.vm_subnet, 1)
      }
    }
  }

  boot_order = ["ide0"]


  lifecycle {
    ignore_changes = [clone[0].vm_id] # template may be replaced; clones must not be recreated
  }
}


output "node" {
  value = local.node
}

output "bridge" {
  value = var.bridge_name
}

output "vms" {
  description = "name, role, VMID, private IP per VM"
  value = [
    for s in local.vm_specs : {
      name = s.name
      role = s.role
      vmid = proxmox_virtual_environment_vm.talos[s.name].vm_id
      ip   = s.ip
    }
  ]
}

variable "start_vms" {
  description = "VM names to power on (host RAM is tight; add workers as memory allows)"
  type        = list(string)
  default     = ["sill-cp1", "sill-w1", "sill-w2"]
}
