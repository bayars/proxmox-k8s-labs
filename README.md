# proxmox-k8s-labs

Terraform configs, scripts and manifests for building Kubernetes lab clusters on **Proxmox VE** and **Google Cloud**.

Each folder is a separate lab with its own Terraform state. They create the machines only; installing Kubernetes (kubeadm, k3s, Kubespray, ...) is up to you.

> These are lab setups, not production infrastructure: TLS verification to Proxmox is off by default, GCP instances get public IPs, and state is stored locally.

## Labs

| Folder | Platform | What it builds |
|---|---|---|
| [`k8s_nodes`](k8s_nodes/) | Proxmox | 4 VMs (1 controller, 3 workers) cloned from a template |
| [`ha_lab`](ha_lab/) | Proxmox | 3 controllers + 1 worker with static IPs via cloud-init, for an HA control plane |
| [`proxmox_dev_vm`](proxmox_dev_vm/) | Proxmox | A single dev VM booted from a Debian ISO |
| [`gcp_lab`](gcp_lab/) | GCP | 3 nodes plus VXLAN and BGP EVPN configs to build an overlay network between them |
| [`gcp_vms`](gcp_vms/) | GCP | 6 instances on a dedicated VPC network |
| [`gcp_ha_scripts`](gcp_ha_scripts/) | GCP | `gcloud` scripts to create and destroy 3 controllers + 3 workers |
| [`k8s_manifests`](k8s_manifests/) | Kubernetes | Ceph CSI (RBD) storage, Grafana and InfluxDB Helm values, a NetworkPolicy demo |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer
- **Proxmox labs:** a Proxmox VE host, an API token, and a cloud-init VM template. See [docs/proxmox-prerequisites.md](docs/proxmox-prerequisites.md).
- **GCP labs:** a GCP project with the Compute Engine API enabled, and the [gcloud CLI](https://cloud.google.com/sdk/docs/install) logged in (`gcloud auth application-default login` for Terraform).

## Quick start

```bash
cd k8s_nodes                                   # pick a lab
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform plan
terraform apply
```

Tear down with `terraform destroy`.

## Secrets

Credentials never go in `.tf` files. Each lab reads them from a `terraform.tfvars` file, which Terraform loads automatically and git ignores. Every lab ships a `terraform.tfvars.example` showing which values to set.

Also git-ignored: `*.tfstate` (state can contain secrets), `.terraform/`, `.env` files, and the real Ceph secret `k8s_manifests/ceph/csi-rbd-secret.yaml`.

## Docs

- [Proxmox prerequisites](docs/proxmox-prerequisites.md): API token and VM template
- [GCP VXLAN / BGP EVPN overlay](docs/gcp-evpn-vxlan.md): how the `gcp_lab` network works and how to verify it
- [Ceph CSI on Proxmox Ceph](docs/ceph-csi.md): using Proxmox's Ceph cluster for Kubernetes volumes

## CI

[`.github/workflows/terraform-fmt.yml`](.github/workflows/terraform-fmt.yml) runs `terraform fmt -check -recursive` on every push to `main` and on every pull request. Run `terraform fmt -recursive` before committing to keep it green.

## License

[Apache 2.0](LICENSE)
