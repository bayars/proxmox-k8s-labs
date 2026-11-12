# sillhome.com on Proxmox (Talos + Cilium + Ceph)

> Moved here from the home-search monorepo. The Helm values it describes stay in the `home-search-deploy` repo (`deploy/values/proxmox*.yaml`, read by `helmfile -e proxmox`) and `./build.sh` lives there too; run those from `/root/home-search-org/home-search-deploy`.

Production stage 1. Everything cluster-side is done and in `deploy/values/proxmox*.yaml`;
the steps below are what only a human with root on the Proxmox host (or DNS/router access) can do.
Do them in order; each ends with a check.

## What exists

| Piece | Where / value |
|---|---|
| Proxmox node | `pve`, 10.0.0.79 (API token `tofu@pam!tofu`, role `TF`, no `Permissions.Modify`) |
| Cluster network | bridge `vmbr2`, host 10.10.10.1/24, no ports, NAT out via `vmbr0` |
| Talos VMs | `sill-cp1` 10.10.10.50 (3 GB), `sill-w1` .51, `sill-w2` .52 (3 GB each); Talos v1.14.5, nocloud image |
| Tofu project | `/root/proxmox-k8s-labs/talos_sillhome` (secrets in `tofu.env`, `_out/`: both gitignored) |
| Kubeconfig / talosconfig | `/root/proxmox-k8s-labs/talos_sillhome/_out/{kubeconfig,talosconfig}` |
| CNI + Gateway | Cilium 1.19 (kube-proxy replacement on), Gateway API CRDs **v1.4.1** + TLSRoute v1alpha2 |
| Gateway address | **10.10.10.60** (Cilium L2 pool in `cilium/l2.yaml`); plain HTTP on port 80, routes match host `sillhome.com`. TLS ends at nginx, not here (`gateway.tls.enabled=false`) |
| nginx VM | existing VM; certbot cert for `sillhome.com`; second NIC `eth1` 10.10.10.5/24 on `vmbr2` (no gateway, `ip_forward` off); config in `nginx/` |
| Cloudflare | DNS, proxy, SSL mode Full (strict); Rogers router forwards TCP 80/443 to the nginx VM |
| Storage | Ceph RBD pool `kubernetes` (size 2, OSDs on sda and sdc) through ceph-csi, StorageClass `ceph-rbd` (default) |
| Images | private `ghcr.io/bayars/home-search/{app,db,haproxy}:0.4.0`; pull secret `ghcr-pull` in ns `home-search` |
| Operators | cert-manager v1.16.2 (unused for the site cert), CloudNativePG 1.24.1 |

Build and push images: `./build.sh app|db|all` (needs `docker login ghcr.io` with a `write:packages` token).
Deploy: `cd deploy && helmfile -e proxmox apply --suppress-diff`.
Do **not** run Helm against a cluster whose control plane is restarting; wait for `kubectl get nodes` to show all Ready.

## 1. Disk roles and Ceph layout

| Disk | Role |
|---|---|
| `sdd` Toshiba 1 TB (USB, JMicron bridge, `uas`) | **Backups only** (scheduled Proxmox backup job). Never in Ceph. |
| `sda` Barracuda 8 TB (SMR) | `osd.0`, LV `barracuda-8TB/ceph1` (200 GB) |
| `sdc` Hitachi 500 GB | `osd.1`, LV `toshiba-500/ceph-osd1` (100 GB) |

Pool `kubernetes`: size 2, min_size 1, rule `rep-osd` (failure domain = OSD). Both OSDs are on one host, so this survives one disk failing, not a host failure.

`sdd` health (2026-11-09): SMART PASSED, 0 reallocated/pending/uncorrectable, one old ICRC link error. Read it with `smartctl -a -d sat /dev/sdd` (the UI shows UNKNOWN because of the USB bridge). It ran at USB 2.0 (480M); move the cable to a USB 3 port (`lsusb -t` shows 5000M). Monitor it: add `/dev/sdd -d sat -a -m root` to `/etc/smartd.conf`, then `systemctl restart smartd`.

`sdc` health: ~44,980 power-on hours, so treat it as expendable. On 2026-11-11, after a full overwrite and read-back: pending sectors 2 to 0, reallocated sectors 0, reallocation events 298 to 308 (flat during the read pass). Run `smartctl -t long /dev/sdc`, then `smartctl -l selftest /dev/sdc`, and re-check `smartctl -a /dev/sdc | grep -E "Reallocated|Pending|Uncorrect"` regularly. If pending sectors return or events keep climbing, replace it:
```bash
ceph osd out osd.1                       # drain; wait for active+clean
ceph osd safe-to-destroy osd.1
systemctl stop ceph-osd@1 && pveceph osd destroy 1 --cleanup 1
```

Backups: Datacenter, Backup, add a job (schedule + retention) with the three Talos VMs, storage on `sdd`. Also take CNPG database backups before upgrades.

Done when `ceph -s` shows HEALTH_OK and all pgs are active+clean.

## 2. Let traffic in: nginx VM to the Gateway

Traffic path:

```
visitor -> Cloudflare (DNS, proxy, SSL Full (strict))
        -> Rogers router (TCP 80/443 forwarded to the nginx VM)
        -> nginx VM (certbot cert, server_name sillhome.com)
        -> eth1 10.10.10.5/24 on vmbr2
        -> Cilium Gateway 10.10.10.60:80 (plain HTTP, L2 announcement)
        -> HAProxy -> web / Keycloak (/idp)
```

This replaces the old plan. The host DNAT lines (PREROUTING 80/443 to 10.10.10.60) and the router forward to 10.0.0.79 are **not used**. The `vmbr2` post-up/post-down DNAT lines have been removed.

1. Give the nginx VM a second network card on bridge `vmbr2`. Set `eth1` to 10.10.10.5/24 with **no gateway**. Keep `ip_forward` off on the VM.
2. On the Rogers router, forward TCP 80 and 443 to the nginx VM.
3. Keep the existing `MASQUERADE` rule and `ip_forward=1` in the `vmbr2` stanza of `/etc/network/interfaces` on the Proxmox host. The Talos nodes still need them for outbound traffic (images, DNS, Let's Encrypt, search).
4. Install the nginx config (see section 3 and `nginx/`).

Check from the nginx VM: `curl -s -H 'Host: sillhome.com' http://10.10.10.60/readyz` returns `{"ready":true,...}`.

## 3. TLS (Let's Encrypt) on the nginx VM

TLS ends at nginx. The in-cluster ClusterIssuer/Certificate path is not used; the values set `gateway.tls.enabled=false`. The ClusterIssuer `letsencrypt-prod` (contact bayarsafa@gmail.com, `cert/clusterissuer.yaml`) still exists but is unused; delete it with `kubectl delete clusterissuer letsencrypt-prod`.

Files in `nginx/` (this repo) and where they go on the nginx VM:

| File | Destination | Notes |
|---|---|---|
| `nginx/sillhome.com.conf` | `/etc/nginx/conf.d/sillhome.com.conf` | Final site config. The `map` block must appear only once in the http context. |
| `nginx/cloudflare-realip.conf` | `/etc/nginx/conf.d/cloudflare-realip.conf` | Cloudflare edge ranges (`set_real_ip_from`), generated 2026-11-11. Auto-included at http level. Refresh from https://www.cloudflare.com/ips-v4 and https://www.cloudflare.com/ips-v6 when Cloudflare changes them. |

Steps:

1. Copy both files, then `nginx -t && nginx -s reload`.
2. Issue the certificate: `certbot --nginx -d sillhome.com`. Auto-renew stays on (`systemctl list-timers | grep certbot`).
3. Keep the port-80 block as a plain redirect only: `return 301 https://$host$request_uri;`.
4. The 443 `location /` must **not** contain a `return`. A stray `return 301` there caused an HTTPS redirect loop on 2026-11-11.

If certbot rewrites the file, compare it with `nginx/sillhome.com.conf` and restore the differences.

Check: `curl -sI https://sillhome.com/readyz` returns 200 with a valid certificate; `curl -sI http://sillhome.com/` returns 301 to https.

## 4. Cloudflare

Phase 1: certificate first (the certificate must exist on nginx before the proxy is on).

1. Add the site `sillhome.com` in Cloudflare.
2. In Namecheap, switch the nameservers to the two Cloudflare ones shown.
3. Add an A record `@` pointing to the home public IP, **DNS only (grey cloud)**.
4. Install `nginx/cloudflare-realip.conf` on the nginx VM **before** enabling the proxy, so `$remote_addr` is the visitor. Otherwise rate limits count Cloudflare addresses.

Phase 2: after `curl -sI https://sillhome.com/readyz` returns 200 with a valid certificate:

1. Turn on **Proxied (orange)** for the A record.
2. SSL/TLS mode: **Full (strict)**. Never Flexible (redirect loop).
3. Always Use HTTPS: on. Minimum TLS version: 1.2.
4. Leave Cloudflare's own HSTS **off**; nginx sends it.

Header chain:

1. Cloudflare sends `X-Forwarded-For` and `CF-Connecting-IP`.
2. nginx restores the visitor address (real_ip) and sets `X-Forwarded-For`.
3. The Cilium Gateway appends the nginx VM address.
4. HAProxy takes the 2nd entry from the right (`haproxy.clientIp.xffFromRight: 2`).
5. web trusts `X-Forwarded-For` only from 10.244.0.0/16 and 10.10.10.5/32 (`web.trustedProxies`).

Certbot renewal works through the proxy (HTTP-01 on port 80). If a renewal ever fails, set the record to DNS only briefly, run `certbot renew`, then turn the proxy back on.

Dynamic home IP: a DDNS updater is **not built yet**. Planned: a CronJob in namespace `ddns` using a Cloudflare API token (Zone:DNS:Edit for `sillhome.com` only), stored as a Kubernetes Secret that you create. Until then, edit the A record by hand if the public IP changes.

Lock the origin to Cloudflare: install `nginx/cloudflare-allow.conf` as `/etc/nginx/conf.d/cloudflare-allow.conf` (it defines `$from_cloudflare` from the same ranges as `cloudflare-realip.conf`; refresh both together). `nginx/sillhome.com.conf` returns 403 in the 443 block when `$from_cloudflare` is 0. It uses `geo $realip_remote_addr` because real_ip rewrites `$remote_addr` to the visitor, so plain `allow/deny` would block Cloudflare itself. Port 80 stays open, so certbot HTTP-01 renewals still work. Test from outside the LAN: `curl -sk --resolve sillhome.com:443:<home-ip> https://sillhome.com/readyz` gives 403, and `curl -sI https://sillhome.com/readyz` gives 200. LAN clients (10.0.0.0/24) are allowed too. Run `nginx -t` before reload.

Check: `curl -sI https://sillhome.com/readyz` returns 200 with `server: cloudflare`; the web logs show the visitor address, not a Cloudflare or 10.x one.

**Keep the Cloudflare ranges fresh (edge case: Cloudflare adds a range).** A stale list gives real visitors a 403 and lets the two files drift apart (rate limits then count Cloudflare addresses). `nginx/update-cloudflare-ranges.sh` regenerates `cloudflare-realip.conf` and `cloudflare-allow.conf` together from Cloudflare's published lists, validates them, runs `nginx -t`, reloads, and restores the old files if the test fails. Install it on the nginx VM and run it weekly:

```
install -m 755 update-cloudflare-ranges.sh /usr/local/sbin/
echo '17 4 * * 1 root /usr/local/sbin/update-cloudflare-ranges.sh 2>&1 | logger -t cf-ranges' > /etc/cron.d/cf-ranges
/usr/local/sbin/update-cloudflare-ranges.sh        # first run, prints "unchanged" or "updated"
```

Origin-lock checks (the lock cannot be tested from the LAN, because the LAN is allowed): from a phone on mobile data, `curl -sk --resolve sillhome.com:443:<home-ip> https://sillhome.com/readyz` must return 403 and `https://sillhome.com/readyz` 200. Cloudflare health checks, uptime monitors and webhooks that call the origin directly are blocked by design; send them through Cloudflare. Optional extra lock: Cloudflare Authenticated Origin Pulls (mTLS with Cloudflare's client certificate).

## NetworkPolicy

Enabled with `networkPolicy.enabled` in `deploy/values/proxmox.app.yaml` (chart `home-search-deploy`). Allowed paths:

- Gateway to HAProxy:8080 only.
- HAProxy to web:8090 and Keycloak:8080.
- web to Keycloak, SearXNG and the DB.
- indexers to SearXNG and the DB.
- Keycloak to the DB.
- CNPG operator to the DB.
- Egress per component to public addresses only (private ranges, 169.254.169.254 and loopback excluded), plus DNS.
- Ollama 10.0.0.224:11434 is allowed by IP.

Verified: the metadata address and the Keycloak admin port 9000 are blocked; the site and the OIDC login redirect still work.

Emergency off switch: `kubectl -n home-search delete networkpolicy --all`. Traffic is restored instantly; the next `helmfile apply` recreates the policies.

Known issue: pods on `vmbr2` cannot reach the LAN Ollama 10.0.0.224. A test from a pod in the `default` namespace (no policy) also times out, so the cause is host NAT/routing for LAN destinations, not the policy. Embeddings fall back to full text. Check on the Proxmox host: `iptables -t nat -S POSTROUTING`, and whether the MASQUERADE rule for 10.10.10.0/24 applies to destinations in 10.0.0.0/24 (a rule such as `! -d 10.0.0.0/24` or an `-o vmbr0` mismatch would skip them).

Check: `kubectl -n home-search get networkpolicy`; `curl -sI https://sillhome.com/readyz` still returns 200.

## Deploy / upgrade

```bash
cd home-search-deploy/deploy && helmfile -e proxmox apply --suppress-diff
```

Images `ghcr.io/bayars/home-search/{app,db,haproxy}:0.4.0` are in the private registry; the pull secret is `ghcr-pull`.

1. Always run `helm template` and diff against `helm get manifest home-search -n home-search` first. An unreviewed apply on 2026-11-11 caused a 3-minute 503 and was rolled back with `helm rollback home-search 1`.
2. The nodes lack memory for a rolling update of the crawl pod. If the new crawl pod stays Pending, scale the old ReplicaSet to 0: `kubectl -n home-search scale rs <old-crawl-rs> --replicas=0`.
3. The CloudNativePG operator pod on `sill-cp1` restarts often because of probe timeouts. If helm fails with `failed calling webhook mcluster.cnpg.io`, wait until `kubectl -n cnpg-system get pods` shows it Ready, then rerun.
4. Keycloak uses its own DB role `keycloak`. The one-time schema ownership move is already done on the live DB (2026-11-11). A pre-upgrade dump is in `_out/homesearch-pre-upgrade-*.dump` (gitignored); move it to the backup disk and delete it later.

Check: `kubectl -n home-search get pods` all Ready; `curl -sI https://sillhome.com/readyz` returns 200.

## 5. Things to clean up on the host (already done once, listed so you can verify)

- No `proxy_arp` on `vmbr0`: `cat /proc/sys/net/ipv4/conf/vmbr0/proxy_arp` should print `0`.
- No leftover `kingston` or `cephfs` storage entries in Datacenter, Storage (they caused the repeated "No mds server" kernel messages).
- `sysctl net.ipv4.ip_forward` is `1` (persisted in `/etc/sysctl.d/99-forward.conf`).

## 6. Disk `/dev/sdc` (Hitachi 466 GB, storage `toshiba-500`)

Not part of the cluster, but SMART shows 2 pending sectors, 297 reallocation events and ~44,900 power-on hours. It holds 128 GB of VM data. Back it up and plan to replace it (`smartctl -a /dev/sdc`).

## 7. Known limits and follow-ups

- **RAM / CPU**: host has ~39 GB total and 6 cores. The control plane hit CPU starvation (RCU stalls) and the API restarted a few times; the NoSchedule taint is back on `sill-cp1`. If it recurs, stop `sill-w2` (set `start_vms` in tofu) or give VMs fewer vCPUs.
- **Hung QEMU**: if a VM's console and agent stop responding (`pvedaemon` logs `qmp ... timeout`), stop and start the VM; the data survives.
- **Changing VM RAM reboots it.** Do it one VM at a time and wait for `kubectl get nodes` to show all Ready.
- **e2e**: runs on its own compose stack, never on the live cluster (the live DB holds real listings): `home-search-e2e/docker-compose.e2e.yml`. For upgrade and rollback checks use `home-search-e2e/scripts/run_upgrade_e2e.sh` with `OLD_IMAGE` and `NEW_IMAGE` set.
- **Ceph copies**: two copies on one host (no host-level redundancy). Keep Proxmox backups of the Talos VMs and take CNPG backups before upgrades.
- **Upgrades**: Talos upgrades keep the Ceph volumes (they are on the host), which is why RBD was chosen over local storage.

### Memory and sizing

- Each node has ~2.4 GB allocatable; before the 2026-11 right-sizing, requests were 76-78% allocated on `sill-cp1`/`sill-w1` and limits 127-202%.
- Measured peak (cgroup `memory.peak`, 2026-11-12): indexer-crawl 1.56 GiB (limit 3 GiB), keycloak 0.65 GiB (1 GiB), web 0.21 GiB (768 MiB), searxng 0.19 GiB, indexer-light 0.12 GiB, HAProxy 0.04 GiB, Postgres 0.42 GiB (1.5 GiB). `kubectl top` does not work (no metrics-server); read `/sys/fs/cgroup/memory.current` with `kubectl exec`.
- `indexer-crawl` and `indexer-light` use `strategy: Recreate` (`values/proxmox.app.yaml`), so a rollout stops the old pod first; it never needs a second crawl pod. Cost: a short gap in crawling during each rollout.
- The CloudNativePG operator is kept off the control plane by node affinity in `helmfile.yaml.gotmpl` (proxmox environment only).
- Host RAM: 39 GB minus VMs 101 (12 GB), 102 (12.4 GB) and the three Talos VMs (9 GB) leaves ~5.6 GB for Proxmox itself, Ceph and cache. Adding 1 GB to each worker (+2 GB) is affordable but leaves ~3.6 GB; prefer `sill-w1` first (highest limit overcommit), one VM at a time.

**Incident 2026-11-12.** sillhome.com returned 503 for several minutes. On 2-vCPU nodes the crawler (Chromium) used the CPU, so the `web` pod on `sill-w1` missed its 1 s probe timeouts and restart-looped (15 restarts). The crawl was scaled to 0 to recover. Separately, `ceph-csi-rbd-provisioner` (on the control plane, no requests) crash-looped about 690 times: its sidecars lost the CSI driver socket and exited; the DB volumes stayed attached, but a new PVC would have hung. Changes: web probe timeouts 5 s, startup window 5 min, liveness tolerates 6 failures, 2 workers, CPU request 250m; crawl gets a 1000m CPU limit, a 250m request and a soft anti-affinity to web; ceph-csi provisioner is kept off the control plane, with sidecar requests and 60 s leader-election leases (`ceph/ceph-csi-rbd-values.yaml`; nodeplugin requests are a separate later step in `ceph/ceph-csi-rbd-values.step2-nodeplugin.yaml`). The crawl comes back with the app release (the chart sets replicas 1), or by `kubectl -n home-search scale deploy/home-search-indexer-crawl --replicas=1`.

