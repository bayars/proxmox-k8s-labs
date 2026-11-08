# gcp_vms

Six Ubuntu 22.04 instances (`e2-standard-4`, `us-central1-a`) with public IPs, on a new auto-mode VPC network.

Resources are named from `name_prefix` (default `k8s-lab`): network `k8s-lab-net`, instances `k8s-lab-0` to `k8s-lab-5`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # gcp_project_id
terraform init
terraform apply
```

> A new VPC network has **no firewall rules**, so SSH and traffic between the instances are blocked until you add some. For example:
>
> ```bash
> gcloud compute firewall-rules create k8s-lab-allow-internal --network k8s-lab-net --allow all --source-ranges 10.128.0.0/9
> gcloud compute firewall-rules create k8s-lab-allow-ssh --network k8s-lab-net --allow tcp:22 --source-ranges <your-ip>/32
> ```
