# Runbook: full reset

Nuke everything and come back to a clean, reproducible state.

```bash
./scripts/down.sh -v      # stops containers AND wipes postgres-data, redis-data, kafka-data
./scripts/up.sh           # fresh boot
./scripts/seed.sh         # recreate Kafka topics
```

## What a fresh boot recreates (in order)

1. **Postgres first-boot init** (`infra/postgres/init/01-init.sh`): roles
   `user_service` / `wallet_service` / `ledger_service` / `keycloak`, schemas
   `users` / `wallet` / `ledger` / `keycloak` (ADR-003).
2. **Keycloak** connects to the `keycloak` schema and imports
   `infra/keycloak/wallet-realm.json` (realm, roles, `local-admin` dev user).
3. **Kafka** starts empty; `seed.sh` creates the topics.
4. **Nginx** boots immediately; `/api/**` routes 502 until services exist.

## When to use

- Init script or realm export changed (they only run on a fresh volume).
- Local state is suspected-bad and debugging is slower than resetting.
- After pulling compose/version changes that alter volume layout.

## Never in shared/staging environments

`down.sh -v` deletes authoritative money data (the ledger lives in Postgres —
ADR-005). Local dev machines only.
