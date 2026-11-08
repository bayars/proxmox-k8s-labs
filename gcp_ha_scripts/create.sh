#!/usr/bin/env bash
set -euo pipefail
: "${GCP_PROJECT:?set GCP_PROJECT (see .env.example)}"
: "${GCP_SERVICE_ACCOUNT:?set GCP_SERVICE_ACCOUNT (see .env.example)}"

for i in {1..3};do
  gcloud compute instances create controller-$i \
      --project="$GCP_PROJECT" \
      --zone=us-central1-c \
      --machine-type=e2-standard-4 \
      --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
      --maintenance-policy=MIGRATE \
      --provisioning-model=STANDARD \
      --service-account="$GCP_SERVICE_ACCOUNT" \
      --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
      --tags=http-server,https-server \
      --create-disk=auto-delete=yes,boot=yes,device-name=controller-$i,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250112,mode=rw,size=40,type=pd-balanced \
      --no-shielded-secure-boot \
      --shielded-vtpm \
      --shielded-integrity-monitoring \
      --labels=goog-ec-src=vm_add-gcloud \
      --reservation-affinity=any
done


for i in {1..3};do
  gcloud compute instances create worker-$i \
      --project="$GCP_PROJECT" \
      --zone=us-central1-c \
      --machine-type=e2-standard-4 \
      --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
      --maintenance-policy=MIGRATE \
      --provisioning-model=STANDARD \
      --service-account="$GCP_SERVICE_ACCOUNT" \
      --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
      --tags=http-server,https-server \
      --create-disk=auto-delete=yes,boot=yes,device-name=worker-$i,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250112,mode=rw,size=40,type=pd-balanced \
      --no-shielded-secure-boot \
      --shielded-vtpm \
      --shielded-integrity-monitoring \
      --labels=goog-ec-src=vm_add-gcloud \
      --reservation-affinity=any
done
