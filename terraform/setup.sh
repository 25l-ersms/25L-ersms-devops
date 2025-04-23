#!/usr/bin/env bash

set -euo pipefail

heading () {
    BLUE_BG=$'\033[44m'
    NC=$'\e[0m'
    echo "${BLUE_BG}$1${NC}"
}

ACCOUNT="$(gcloud config get core/account)"
PROJECT="$(gcloud config get core/project)"

heading "Logged in as $ACCOUNT, using project $PROJECT"

if [[ -f providers.tf && -f terraform.tfvars ]]; then
    echo "Terraform config already present, skipping creation"
else
    AVAILABLE_REGIONS="$(gcloud compute regions list --format 'json(name)' | jq -r '.[] | .name')"
    REGION=""
    read -p "Enter GCP region: " REGION

    if ! [[ "$AVAILABLE_REGIONS" =~ "$REGION" ]]; then
        echo "$REGION is not a valid region"
        exit 1
    fi

    RESOURCE_PREFIX=""
    read -p "Enter resource prefix: " RESOURCE_PREFIX

    heading "Writing terraform config..."
    sed -E "s#\{\{gcp_project\}\}#$PROJECT#gm" sample/providers.tf.sample | \
        sed -E "s#\{\{gcp_state_bucket\}\}#$RESOURCE_PREFIX-terraform-state#gm" | \
        sed -E "s#\{\{gcp_region\}\}#$REGION#gm" > providers.tf

    sed -E "s#\{\{resource_prefix\}\}#$RESOURCE_PREFIX#gm" sample/terraform.tfvars.sample > terraform.tfvars


    heading "Creating remote backend..."
    gcloud storage buckets create "gs://$RESOURCE_PREFIX-terraform-state" \
        --project="$PROJECT" \
        --location="$REGION" \
        --uniform-bucket-level-access \
        --public-access-prevention
fi

heading "Enabling APIs..."
(
    set -x
    gcloud services enable \
        compute.googleapis.com \
        storage.googleapis.com \
        run.googleapis.com \
        cloudbuild.googleapis.com \
        servicenetworking.googleapis.com \
        sqladmin.googleapis.com \
        managedkafka.googleapis.com \
        container.googleapis.com \
        cloudresourcemanager.googleapis.com \
        dns.googleapis.com \
        iamcredentials.googleapis.com \
        secretmanager.googleapis.com \
        firestore.googleapis.com
)

heading "Initializing terraform..."
terraform init

heading "All done!"
