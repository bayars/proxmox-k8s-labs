# k8s_manifests

Kubernetes manifests and Helm values used on the lab clusters.

| Path | What it is |
|---|---|
| `ceph/` | Ceph CSI RBD driver, config and storage class `csi-rbd-sc`, to use Proxmox's Ceph cluster for volumes. Setup: [docs/ceph-csi.md](../docs/ceph-csi.md) |
| `grafana.yaml` | Values for the `grafana/grafana` Helm chart, exposed as a NodePort service |
| `influxvalues.yaml` | Values for the `influxdata/influxdb` Helm chart: InfluxDB 2 image, 8 GiB volume on `csi-rbd-sc`, NodePort 30012 |
| `nw-policy.yaml` | NetworkPolicy demo (see below) |

## Helm charts

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add influxdata https://helm.influxdata.com
helm install grafana grafana/grafana -f grafana.yaml
helm install influxdb influxdata/influxdb -f influxvalues.yaml
```

Grafana creates a random admin password in the `grafana` secret:

```bash
kubectl get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

## NetworkPolicy demo

`nw-policy.yaml` creates an nginx pod `lab9server` in namespace `lab9server`, two busybox client pods in `default`, and a policy that lets only pods labeled `access: "yes"` from `default` reach it on TCP 80.

```bash
kubectl create namespace lab9server
kubectl apply -f nw-policy.yaml
IP=$(kubectl -n lab9server get pod lab9server -o jsonpath='{.status.podIP}')
kubectl exec sleepybox1 -- wget -qO- -T 3 $IP   # allowed
kubectl exec sleepybox2 -- wget -qO- -T 3 $IP   # times out
```

Your CNI must enforce NetworkPolicy (Calico, Cilium, ...); Flannel alone doesn't.
