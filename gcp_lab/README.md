# gcp_lab

Three Ubuntu 22.04 nodes on GCP (`k8s-controller`, `k8s-worker1`, `k8s-worker2`, `n1-standard-4`, `us-central1-a`) on the `default` network, plus netplan and FRR configs to join them into a VXLAN overlay with BGP EVPN.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # gcp_project_id
terraform init
terraform apply
```

Outputs: public IPs of the controller and worker1.

Then set up the overlay with the files in this folder by following [docs/gcp-evpn-vxlan.md](../docs/gcp-evpn-vxlan.md).

| File | Purpose |
|---|---|
| `*.netplan` | VXLAN tunnels and `br0` bridge for each node |
| `*.frr` | FRR BGP EVPN config for each node |
| `conf.txt` | Earlier single-VNI version, kept for reference |
