# proxmox_dev_vm

A single development VM, `dev-machine`, that boots the Debian 11 netinst ISO so you can install the OS through the Proxmox console.

8 GB RAM, 3 cores (host CPU type), a 32 GB disk on storage `plex`, `virtio` NIC on `vmbr0` with the Proxmox firewall on, node `proxmox`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # Proxmox URL and API token
terraform init
terraform apply
```

The ISO `local:iso/debian-11.2.0-amd64-netinst.iso` must already be uploaded to the host. Change node, storage and ISO in `main.tf` to match your setup.

> This lab uses the Telmate provider **2.9.10**, while the other Proxmox labs use 3.0.1-rc6. The two versions use different config syntax, so don't copy blocks between them without converting.
