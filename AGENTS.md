# AGENTS.md — workspace orchestration repo

AI steering for this repo. The system design (`wallet-system-design.md`) is the
authoritative reference; this file is the operating rules.

## The contract rule (non-negotiable, design §8)

`contracts/` is the source of truth for every service API. **Any change to
`contracts/` must update `backend/` and `frontend/` in the same change window.**
No contract files exist yet — do not invent endpoints here. When service detail
arrives, add `contracts/openapi-<service>.yaml` first, then generate BE stubs +
FE clients from it.

## What lives here (design §2)

Infra as code only. **No service code, ever** — services live in the separate
`backend/` and `frontend/` repos.

```
infra/compose/     docker-compose.base.yml (shared defaults) + .dev.yml + .prod.yml overlays
infra/nginx/       gateway: nginx.conf + conf.d/gateway.conf (env variants added with TLS)
infra/keycloak/    versioned realm export (wallet-realm.json)
infra/postgres/    init script: one role + one schema per service (runs on first volume boot)
infra/observability/  phase 2 (prometheus/grafana/otel)
contracts/         openapi per service (empty — waiting on service detail)
docs/architecture/ ADRs 001-008
docs/runbooks/     up / down / seed / debug / reset
scripts/           up.sh down.sh seed.sh contract-check.sh
```

## Commands

| Command | What it does |
|---|---|
| `./scripts/up.sh` | boot full stack (base + dev overlay, waits for health) |
| `./scripts/up.sh prod` | boot with prod overlay |
| `./scripts/down.sh` | stop; `./scripts/down.sh -v` also wipes all data volumes |
| `./scripts/seed.sh` | create Kafka topics as code (auto-create is off); demo data later |
| `./scripts/contract-check.sh` | validate contracts; CI gate |

Never commit `.env` — only `.env.example`. If you add an infra variable, update
`.env.example` in the same change.

## Infra rules

- Compose/nginx/realm changes are reviewed like code (§2).
- One Postgres instance, one schema per service (`users`, `wallet`, `ledger`,
  plus `keycloak`), separate roles, **no cross-schema queries — ever** (ADR-003).
  Flyway migrations are owned per service; `infra/postgres/init` only creates
  the boundaries.
- Money rules (§3, non-negotiable, applies to contracts too): amounts are
  `BIGINT` minor units — never floats; append-only ledger + balance update in
  one ACID transaction; idempotency keys on payment/transfer endpoints; Kafka
  events published after commit via the transactional outbox.
- Kafka topics are code: `<service>-events` + `<service>-events.dlq`, created by
  `scripts/seed.sh`; auto-create stays off.
- Redis is disposable (ADR-007): read-path caching, idempotency keys, token
  blacklist, rate limits — never authoritative for money.
- Nginx stays dumb: static routing + timeouts; breakers live in services
  (ADR-001, ADR-008).
- New stack or infra decision → write an ADR in `docs/architecture/` with the
  next number, and update the ADR index there.

## Dev ports (all loopback-only)

| Service | Host | Container |
|---|---|---|
| Nginx gateway | 8080 | 80 |
| Keycloak | 8180 | 8080 |
| PostgreSQL | 5432 | 5432 |
| Redis | 6379 | 6379 |
| Kafka (host listener) | 9092 | 9092 (broker-internal 29092) |
