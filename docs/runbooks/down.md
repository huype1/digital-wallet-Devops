# Runbook: stop the stack

## Stop (keep data)

```bash
./scripts/down.sh
```

Stops and removes containers; named volumes (`postgres-data`, `redis-data`,
`kafka-data`) are kept. Next `./scripts/up.sh` restores everything — Postgres
init scripts do **not** re-run (they only run on first volume boot).

## Stop and wipe everything

```bash
./scripts/down.sh -v
```

Also deletes all data volumes: database rows, Kafka topics, Keycloak realm DB,
Redis cache. The next `up.sh` re-runs `infra/postgres/init/01-init.sh` (fresh
schemas + roles) and re-imports `infra/keycloak/wallet-realm.json`.

## Notes

- Prod overlay: `./scripts/down.sh --prod` (data volumes are shared with dev
  unless you override volume names).
- `-v` is passed straight to `docker compose down` — there is no undo.
