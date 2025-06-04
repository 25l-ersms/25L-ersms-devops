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

# create an SA in a service namespace (example: visit scheduler)
kubectl apply -f k8s_configs/visit_sched/visit_sched_external_secrets_sa.yml

# create a namespace-scoped secret store
kubectl apply -f k8s_configs/visit_sched/visit_sched_secret_store.yml

# create secrets from secret manager
kubectl apply -f k8s_configs/visit_sched/visit_sched_secrets.yml

# check whether external-secrets has successfully created secrets
kubectl get secrets -n visit-sched-ns
```
