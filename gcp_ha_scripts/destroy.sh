#!/usr/bin/env bash
set -euo pipefail
: "${GCP_PROJECT:?set GCP_PROJECT (see .env.example)}"

for i in {1..3};do
  gcloud compute instances delete controller-$i \
      --project="$GCP_PROJECT" \
      --quiet \
      --zone=us-central1-c 
done


for i in {1..3};do
  gcloud compute instances delete worker-$i \
      --project="$GCP_PROJECT" \
      --quiet \
      --zone=us-central1-c 
done
