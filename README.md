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
