# k8s_nodes

Four Proxmox VMs for a basic Kubernetes cluster: `k8s-controller`, `k8s-worker1`, `k8s-worker2`, `k8s-worker3`.

Each VM is a full clone of a cloud-init template with 2 cores, 2 GB RAM, a 20 GB disk on `local` storage, and a `virtio` NIC on `vmbr0`. The QEMU guest agent is enabled and VMs start on boot. IPs come from DHCP.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # Proxmox URL and API token
terraform init
terraform apply
```

Output: `vm_names`.

## Settings

Edit `vm_base_config` and `vm_names` in `main.tf`. Make sure `template` matches a template on your host; see [Proxmox prerequisites](../docs/proxmox-prerequisites.md).
