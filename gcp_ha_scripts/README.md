# gcp_ha_scripts

`gcloud` scripts that create and delete six instances for an HA Kubernetes cluster: `controller-1..3` and `worker-1..3`.

Each is `e2-standard-4` in `us-central1-c` on the `default` network, with a 40 GB `pd-balanced` Ubuntu 22.04 disk and the `http-server` / `https-server` tags.

## Usage

```bash
cp .env.example .env    # set GCP_PROJECT and GCP_SERVICE_ACCOUNT
source .env
./create.sh             # create all six instances
./destroy.sh            # delete them
```

`GCP_SERVICE_ACCOUNT` is usually the Compute Engine default account, `<project-number>-compute@developer.gserviceaccount.com`. Find the project number with `gcloud projects describe $GCP_PROJECT --format='value(projectNumber)'`.

The boot image is pinned to `ubuntu-2204-jammy-v20250112`. Update it in `create.sh` if GCP has retired that image.
