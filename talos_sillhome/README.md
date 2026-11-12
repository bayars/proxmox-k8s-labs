# talos_sillhome — Talos k8s cluster on Proxmox (sillhome.com production stage)

OpenTofu module (bpg/proxmox provider 0.120.0, API-token only access).
Separate from the Telmate modules in this repo — uses its own provider.
Validated with `tofu validate` (OpenTofu 1.13.9).

## Layout
- `vmbr1` — new private bridge (host holds `10.10.10.1/24`)
- VMs cloned from the Talos nocloud template (schematic `86ab54e6…`, ctr + gvisor):
  1× control-plane `sill-cp1` + 2× workers `sill-w{1,2}`, static IPs `10.10.10.50/51/52`
  delivered via the cloud-init (NoCloud) drive, which the Talos nocloud platform reads.

## Run
```bash
# creds (never committed):  /root/home-search/.env
source /root/home-search/.env
export TF_VAR_pm_token_id="$TF_TOKEN_ID" TF_VAR_pm_token_secret="$TF_SECRET"
# put endpoint + template id in terraform.tfvars (gitignored):
#   pm_endpoint    = "https://<node-ip>:8006/"
#   template_vm_id = 9001
tofu init
tofu plan
tofu apply
```

## One-time host bits (via API, no SSH)
- **SNAT** for the VM subnet (after `terraform apply`, from this machine):
  `curl -k -X POST https://<node>:8006/api2/json/cluster/firewall/rules -d '...type=out,source=10.10.10.0/24,macro?...'`
  (see run log for the exact call used)
- **Port forwards** on the node LAN IP for ingress and talosctl (also via API/raw, DNAT
  rules or firewall NAT) — recorded in the run log when applied.

## State
`terraform.tfstate` stays here and is gitignored. This repo has no remote for it —
if state matters later, move to a backend.
