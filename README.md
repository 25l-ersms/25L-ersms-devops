# ERSMS

## Development
### Use docker compose

copy env file:
```
cp .env.sample .env
```

change values inside .env (eg. paths)

run containers:
```
docker compose --env-file .env up --build
```

## Prod (sortof, like local prod? maybe staging?)
### Prerequisites

`gcloud` CLI authenticated and pointing to the desired project.

### Setup

```shell
chmod +x setup.sh
./setup.sh
```

