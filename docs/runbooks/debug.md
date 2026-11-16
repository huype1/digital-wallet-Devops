# Runbook: debug

## Overall health

```bash
./scripts/up.sh                       # --wait prints which service is stuck
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml ps
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml logs -f [service]
```

## PostgreSQL

```bash
# shell into the instance (superuser)
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec postgres psql -U wallet_admin -d wallet_platform

# connect AS a service role to prove isolation (ADR-003)
psql "host=localhost port=5432 dbname=wallet_platform user=wallet_service password=<from .env>"

# boundaries: roles + schemas
\du
\dn+
```

## Redis

```bash
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec redis redis-cli
#> ping / KEYS '*' / FLUSHALL  (Redis is disposable — flushing must never corrupt anything, ADR-007)
```

## Kafka

```bash
# list topics / consumer groups / lag
... exec kafka kafka-topics --bootstrap-server localhost:9092 --list
... exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --all-groups --describe
```

DLQ topics (`<service>-events.dlq`) non-empty = a consumer failed past its
retries (design §7) — check the consuming service's logs first.

## Keycloak

- Admin console: http://localhost:8180 (bootstrap admin from `.env`)
- Health endpoint lives on the management port (9000) inside the container:

```bash
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec keycloak curl -sf http://localhost:9000/health
```

## Nginx gateway

```bash
curl -i http://localhost:8080/api/wallet/balance   # 502 = upstream absent (services not deployed yet)
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec nginx nginx -t                              # validate config after edits
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec nginx nginx -s reload                       # hot reload (conf.d is bind-mounted)
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  logs nginx                                       # access log carries rid=$request_id
```

## Common issues

| Symptom | Cause / fix |
|---|---|
| Gateway 502 on every `/api/**` route | Expected until `backend/` services are added to compose |
| `up.sh` hangs on keycloak | First boot creates the `keycloak` schema — takes up to ~90 s |
| Kafka topics missing after restart | Auto-create is off; run `./scripts/seed.sh` |
| Schemas missing | Init runs only on first volume boot — `./scripts/down.sh -v` then `up.sh` |
