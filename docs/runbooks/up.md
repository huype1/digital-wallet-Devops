# Runbook: start the stack

## Prerequisites

- Docker Engine 29+ with Compose v2 (`docker compose version`)
- bash

## First run

```bash
cp .env.example .env    # edit the passwords
./scripts/up.sh
```

`up.sh` merges `docker-compose.base.yml` + `docker-compose.dev.yml`, starts
everything, and waits until every service reports healthy.

## What boots (dev, all loopback-only)

| Endpoint | URL | Notes |
|---|---|---|
| Nginx gateway | http://localhost:8080 | `/api/users/**`, `/api/wallet/**`, `/api/ledger/**` — 502 until services exist |
| Keycloak | http://localhost:8180 | realm `wallet`, bootstrap admin from `.env`, dev user `local-admin` / `local-admin` |
| PostgreSQL | localhost:5432 | `wallet_platform` DB, schemas `users` / `wallet` / `ledger` / `keycloak` |
| Redis | localhost:6379 | |
| Kafka (host listener) | localhost:9092 | broker-internal listener is `kafka:29092` |

## Verify

```bash
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml ps
```

Every service should be `healthy`. Kafka starts slower than the rest
(`start_period: 40s`), Keycloak slowest (`start_period: 90s`).

## Prod overlay

```bash
./scripts/up.sh prod
```

Same infra, resource limits applied, only the gateway is published (80/443),
debug ports closed. Service definitions are added to the prod overlay as CI
publishes images (design §9).

## Troubleshooting

- **Port already in use** — all dev ports bind `127.0.0.1`; check `lsof -i :8080` etc.
- **Postgres volume exists but schemas missing** — init scripts run only on
  *first* volume boot; wipe with `./scripts/down.sh -v` to re-run them.
