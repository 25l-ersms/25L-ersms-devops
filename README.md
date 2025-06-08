# ERSMS

## Development
### Use docker compose
enter development folder:
```
cd development
```

copy env file and example configs:
```
cp .env.sample .env
cp development/docker.sample development/docker
```

change values inside .env (eg. paths)

run containers:
```
docker compose --env-file .env up --build --detach && docker compose logs --follow
```

### useful  commands:
log onto postgres:
```
psql -d visit_manager -U postgres
```

### Accessing PgAdmin4

PgAdmin4 is running on port 8888 with a pre-configured server, login using credentials from docker compose file, find PG password in envfile.

## Prod (sortof, like personal prod? maybe staging?)

### Prerequisites

`gcloud` CLI authenticated and pointing to the desired project.

### Setup

```shell
chmod +x setup.sh
./setup.sh
```

### Stripe API Key

To obtain the Stripe API key, follow these steps:
1. Log in / Create a Stripe account [Stripe dashboard](https://dashboard.stripe.com/).
2. Go to the [Test home page](https://dashboard.stripe.com/test/dashboard)
3. Copy `Secret key` and paste it in the `.env` file as `STRIPE_API_KEY`.

## GKE guide

### Access GKE cluster through a bastion host

Open a SOCKS5 proxy on bastion:

```shell
# keep this shell open or add -f flag to run in background
gcloud compute ssh --zone "<REGION>-a" "<RESOURCE_PROFIX>-bastion" --project "<PROJECT>" -- -p 2222 -q -D 1337 -N -v
```

Install GKE auth plugin and authenticate:

```shell
# for debian-based distros
sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

# authenticate against GKE
# note: you will need to re-run this if you recreate the cluster, even if all names match
gcloud container clusters get-credentials <RESOURCE_PREFIX>-gke --region==<REGION>-a --project=<PROJECT>
```

Run `kubectl` commands:

```shell
HTTPS_PROXY=socks5://localhost:1337 kubectl get pods
```

### Setting up external-secrets

Needs to be done before deploying workloads

```shell
# Add the Helm repository
helm repo add external-secrets https://charts.external-secrets.io

# Update Helm repos
helm repo update

# Install ESO with CRDs
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true

# annotate the AS from helm chart
kubectl annotate serviceaccount external-secrets \
  -n external-secrets \
  iam.gke.io/gcp-service-account=<RESOURCE_PREFIX>-eso@<PROJECT_ID>.iam.gserviceaccount.com
```

### Generating certificates for backend pods

Needs to be done before deploying workloads

```shell
# repeat for visit sched and user chat

SVC="visit-man"
SVC_NAME="visit_man"

openssl genrsa -out "$SVC.key" 2048
openssl req -new -key "$SVC.key" -subj "/CN=$SVC-service.$SVC-ns.svc.ersms-gke" -out "$SVC.csr"

sed "s/{{B64_CSR}}/`cat $SVC.csr | base64 | tr -d '\n'`/" k8s_configs/$SVC_NAME/${SVC_NAME}_csr.yml.template > k8s_configs/$SVC_NAME/${SVC_NAME}_csr.yml

kubectl apply -f k8s_configs/$SVC_NAME/${SVC_NAME}_csr.yml
kubectl certificate approve "$SVC"

kubectl get csr "$SVC" -o jsonpath='{.status.certificate}' | base64 --decode > $SVC.crt

kubectl create secret tls $SVC-tls --cert=$SVC.crt --key=$SVC.key -n ${SVC}-ns
```

### Creating resources

First create gateway and gateway http redirect.

Then, apply in order for each servive:

- ns
- sa
- external secrets sa
- secret store
- secrets
- configmap
- deployment
- service
- ~~ingress~~ (deprecated)
- healthcheck
- httproute

### Setting up the LB

Googles ingress controller is too dumb to handle multiple ingress resources with a single LB, therefore we need to create it ourselves.

> TODO ssl passthrough on LB

- Go to LB page on GCP console
- create external global ALB
  - add frontend with the provisioned IP, https, auto redirect, set ssl policy to min tls 1.2
  - for each service add backend with a corresponding zonal NEG (should be created automatically), create HTTP healthcheck pointing to `/api/<visit-sched|visit-man|user-chat>/docs`
  - Route based on path `/api/<visit-sched|visit-man|user-chat>/*`, origin is always `*`
  - Wait a few minutes :) (even if google claims the LB is up and running)
