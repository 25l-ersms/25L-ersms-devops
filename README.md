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
development/docker.sample development/docker
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
