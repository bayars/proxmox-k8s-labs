# Ceph CSI on Proxmox Ceph

`k8s_manifests/ceph` connects a Kubernetes cluster to the Ceph cluster that Proxmox VE runs, using [ceph-csi](https://github.com/ceph/ceph-csi) with RBD block images. Volumes requested from the `csi-rbd-sc` storage class become RBD images in a Ceph pool named `kubernetes`.

## 1. Prepare Ceph (on a Proxmox node)

```bash
# Pool for Kubernetes volumes
pveceph pool create kubernetes
rbd pool init kubernetes

# Ceph user for the CSI driver
ceph auth get-or-create client.kubernetes \
  mon 'profile rbd' \
  osd 'profile rbd pool=kubernetes' \
  mgr 'profile rbd pool=kubernetes'

# Values needed below
ceph fsid               # cluster ID
ceph mon dump           # monitor addresses
ceph auth get-key client.kubernetes
```

## 2. Fill in your values

| File | Field | Value |
|---|---|---|
| `csi-config-map.yml` | `clusterID`, `monitors` | `ceph fsid`, monitor address(es) on port 3300 |
| `csi-rbd-sc.yaml` | `clusterID` | `ceph fsid` |
| `csi-rbd-secret.yaml` | `userKey` | output of `ceph auth get-key client.kubernetes` |

The secret file is git-ignored. Create it from the example:

```bash
cp ceph/csi-rbd-secret.yaml.example ceph/csi-rbd-secret.yaml
```

## 3. Deploy

The driver manifests reference the `rbd-csi-provisioner` and `rbd-csi-nodeplugin` service accounts, whose RBAC rules aren't in this repo. Apply them and the `CSIDriver` object from the ceph-csi repo first, using the release that matches the image you run:

```bash
CEPH_CSI=https://raw.githubusercontent.com/ceph/ceph-csi/devel/deploy/rbd/kubernetes
kubectl apply -f $CEPH_CSI/csidriver.yaml
kubectl apply -f $CEPH_CSI/csi-provisioner-rbac.yaml
kubectl apply -f $CEPH_CSI/csi-nodeplugin-rbac.yaml
```

Then apply the manifests here:

```bash
kubectl apply -f ceph/
```

Everything is deployed in the `default` namespace, and `csi-rbd-sc` is marked as the default storage class.

> The plugin images use the `quay.io/cephcsi/cephcsi:canary` tag (the development build). For a more stable setup, pin a released version (for example `v3.12.x`) in `csi-rbdplugin.yaml` and `csi-rbdplugin-provisioner.yaml`, and use the RBAC files from the same release branch.

## 4. Test

`raw-block-pvc.yaml` requests a 1 GiB raw block volume:

```bash
kubectl get pvc raw-block-pvc     # STATUS should be Bound
rbd ls kubernetes                 # on Proxmox: a csi-vol-... image appears
```

## Using it with the Helm values

`influxvalues.yaml` stores InfluxDB data on `csi-rbd-sc` (8 GiB) and exposes it on NodePort 30012. See [`k8s_manifests/README.md`](../k8s_manifests/README.md).
