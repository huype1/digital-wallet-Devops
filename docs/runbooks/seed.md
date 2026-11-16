# Runbook: seed data

## What `seed.sh` does now

Kafka topics are **created as code** — auto-create stays off (design §3):

```bash
./scripts/seed.sh
```

Creates, for each producing service, a main topic + DLQ (3 partitions, RF 1):

- `user-events`, `user-events.dlq` — e.g. `UserRegistered`
- `wallet-events`, `wallet-events.dlq` — e.g. `WalletCredited`, `WalletDebited`

Events are published **after commit** by each service via the transactional
outbox (ADR-004/005).

## What comes later

Once the service contracts land (`contracts/openapi-*.yaml`), `seed.sh` grows a
demo-data section that calls the gateway API (demo users, wallets, a few
transfers). Until then it only creates topics.

## Inspecting topics

```bash
docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec kafka kafka-topics --bootstrap-server localhost:9092 --list

docker compose -f infra/compose/docker-compose.base.yml -f infra/compose/docker-compose.dev.yml \
  exec kafka kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic wallet-events --from-beginning
```
