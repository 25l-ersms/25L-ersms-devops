# ERSMS

## Development
### Use docker compose
enter development folder:
```
cd development
```

copy env file:
```
cp .env.sample .env
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

## Prod (sortof, like personal prod? maybe staging?)
### Prerequisites

`gcloud` CLI authenticated and pointing to the desired project.

### Setup

```shell
chmod +x setup.sh
./setup.sh
```

