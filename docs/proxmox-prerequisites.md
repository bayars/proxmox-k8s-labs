# Proxmox prerequisites

The Proxmox labs (`k8s_nodes`, `ha_lab`, `proxmox_dev_vm`) use the [Telmate Proxmox provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs). Before running them you need an API token and, for the clone-based labs, a VM template.

## 1. Create an API token

On the Proxmox host:

```bash
pveum user token add root@pam terraform --privsep 0
```

This prints the token secret **once**. Put it in the lab's `terraform.tfvars`:

```hcl
pm_api_url          = "https://<proxmox-host>:8006/api2/json"
pm_api_token_id     = "root@pam!terraform"
pm_api_token_secret = "<secret printed above>"
```

`--privsep 0` gives the token the same rights as `root@pam`, which is fine for a lab. For anything shared, create a dedicated user and role with only the VM permissions Terraform needs (see the provider docs).

To revoke a token later: `pveum user token remove root@pam terraform`.

## 2. Create a cloud-init VM template

`k8s_nodes` and `ha_lab` clone a template instead of installing an OS. Build one from the Ubuntu cloud image:

```bash
# On the Proxmox host
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

qm create 9000 --name k8s-node --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --agent 1
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0 --boot order=scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --ciuser ubuntu --sshkeys ~/.ssh/id_ed25519.pub
qm template 9000
```

Template names the labs expect (change them in the lab if yours differ):

| Lab | Template name | Where to change it |
|---|---|---|
| `ha_lab` | `k8s-node` | `variable "template"` in `main.tf` |
| `k8s_nodes` | `ubuntu-22.04-template` | `vm_base_config.template` in `main.tf` |

The labs don't set a login user or SSH key, so the template's cloud-init user and key (`--ciuser`, `--sshkeys` above) are what you log in with.

## 3. Check names that differ between setups

These are hardcoded in the labs and may not match your host:

| Setting | Value used | Check with |
|---|---|---|
| Node name | `pve` (`proxmox` in `proxmox_dev_vm`) | `pvecm nodes` or the Proxmox UI |
| Bridge | `vmbr0` | `ip link show type bridge` |
| Storage | `local-lvm` (`ha_lab`), `local` (`k8s_nodes`), `plex` (`proxmox_dev_vm`) | `pvesm status` |

The disk size a lab sets must be at least the template's disk size, or the clone fails.
