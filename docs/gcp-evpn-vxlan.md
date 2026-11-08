# GCP VXLAN / BGP EVPN overlay

`gcp_lab` builds three Ubuntu nodes on GCP's `default` network and joins them into a private Layer 2 overlay (`172.20.10.0/24`) using VXLAN tunnels, with FRR running BGP EVPN over the overlay. This lets you experiment with EVPN-style networking for Kubernetes without any physical switches.

## Topology

```mermaid
flowchart LR
  subgraph GCP default network - underlay 10.128.0.0/20
    C["k8s-controller<br/>underlay 10.128.0.31<br/>overlay 172.20.10.1"]
    W1["k8s-worker1<br/>underlay 10.128.0.32<br/>overlay 172.20.10.102"]
    W2["k8s-worker2<br/>underlay 10.128.0.30<br/>overlay 172.20.10.101"]
  end
  C <-- "VXLAN VNI 100" --> W1
  C <-- "VXLAN VNI 110" --> W2
  W1 <-- "VXLAN VNI 110" --> W2
```

Each node has two VXLAN tunnels (`vxlan100`, `vxlan110`, UDP 4789) to the other two nodes, attached to a bridge `br0` that holds the node's overlay IP. All three nodes peer with each other in iBGP AS 65000 over the overlay and exchange EVPN routes (`advertise-all-vni`).

| Node | Underlay IP | Overlay IP (`br0`) | Netplan | FRR |
|---|---|---|---|---|
| k8s-controller | 10.128.0.31 | 172.20.10.1 | `controller.netplan` | `controller.frr` |
| k8s-worker1 | 10.128.0.32 | 172.20.10.102 | `worker1.netplan` | `worker1.frr` |
| k8s-worker2 | 10.128.0.30 | 172.20.10.101 | `worker2.netplan` | `worker2.frr` |

## Steps

### 1. Create the nodes

```bash
cd gcp_lab
cp terraform.tfvars.example terraform.tfvars   # set gcp_project_id
terraform init && terraform apply
```

All nodes have `can_ip_forward = true` so they can route overlay traffic.

### 2. Update the underlay IPs

GCP assigns internal IPs dynamically, so yours will differ from the ones in the netplan files. Get them with:

```bash
gcloud compute instances list --format="table(name,networkInterfaces[0].networkIP)"
```

Then edit `local:` and `remote:` in each `*.netplan` file to match.

The `ethernets` section (`ens5`, `ens6`) in `controller.netplan` is for a multi-NIC variant (the extra networks commented out in `main.tf`). With the default single-NIC setup, remove it.

### 3. Apply netplan on each node

```bash
sudo cp controller.netplan /etc/netplan/60-vxlan.yaml   # use the node's own file
sudo chmod 600 /etc/netplan/60-vxlan.yaml
sudo netplan apply
ip -d link show vxlan100
ping 172.20.10.102                                      # another node's overlay IP
```

### 4. Install and configure FRR

```bash
sudo apt-get install -y frr
sudo sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo cp controller.frr /etc/frr/frr.conf                # use the node's own file
sudo systemctl restart frr
```

### 5. Verify

Run `sudo vtysh`, then:

```
show ip bgp summary
show bgp l2vpn evpn summary
show bgp ipv4
show ip bgp neighbors 172.20.10.102
```

All neighbors should be `Established` in `show bgp l2vpn evpn summary`.

## Firewall

GCP's `default` network has the `default-allow-internal` rule, which allows all traffic between instances in `10.128.0.0/9`, including VXLAN (UDP 4789). BGP runs inside the overlay, so it needs no extra rule. If you use a custom network instead, allow UDP 4789 between the nodes.

## `conf.txt`

`conf.txt` holds an earlier version of this setup: a single VNI 10 tunnel created with `ip link add`, and FRR peering on the underlay IPs instead of the overlay. It's kept for reference; the `*.netplan` and `*.frr` files are the current configuration.
