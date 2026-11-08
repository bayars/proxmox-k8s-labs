# ha_lab

Four Proxmox VMs for a highly available control plane: three controllers and one worker, each with a static IP set through cloud-init.

| VM | IP |
|---|---|
| controller-1 | 10.0.0.101/24 |
| controller-2 | 10.0.0.102/24 |
| controller-3 | 10.0.0.103/24 |
| worker-1 | 10.0.0.104/24 |

Gateway `10.0.0.1`. Change names and IPs in `variable "network_config"` in `main.tf`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # Proxmox URL and API token
terraform init
terraform apply
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `template` | `k8s-node` | Template to clone |
| `vm_cores` | `2` | vCPU cores per VM |
| `vm_memory` | `2048` | Memory in MB |
| `vm_disk_size` | `20G` | Boot disk size, at least the template's |
| `vm_storage` | `local-lvm` | Storage for boot and cloud-init disks |

Override any of them in `terraform.tfvars`. For an HA control plane you'll also need a load balancer or virtual IP in front of the three API servers (for example kube-vip or HAProxy + keepalived).
