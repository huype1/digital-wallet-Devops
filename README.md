# Digital Wallet Platform — orchestration workspace

Infra-as-code for the digital wallet platform described in
[`wallet-system-design.md`](wallet-system-design.md): Nginx API gateway,
Keycloak, PostgreSQL (schema-per-service), Kafka (KRaft), Redis.

Service code lives in the separate `backend/` and `frontend/` repos — nothing
here (design §2).

## Quickstart

```bash
cp .env.example .env      # then edit the passwords
./scripts/up.sh           # boots base + dev overlay, waits until healthy
./scripts/seed.sh         # creates Kafka topics (auto-create is off)
```

- Gateway:   http://localhost:8080 (502 until services exist)
- Keycloak:  http://localhost:8180 — bootstrap admin from `.env`, realm `wallet`,
  dev user `local-admin` / `local-admin`
- Teardown: `./scripts/down.sh` (keep data) or `./scripts/down.sh -v` (wipe)

## Layout

```
infra/
├── compose/          docker-compose.base.yml + .dev.yml + .prod.yml overlays
├── nginx/            gateway config (nginx.conf, conf.d/gateway.conf)
├── keycloak/         versioned realm export
├── postgres/init/    creates per-service roles + schemas on first boot
└── observability/    phase 2 placeholder
contracts/            openapi per service (empty — contract-first, design §8)
docs/
├── architecture/     ADR-001 … ADR-008
└── runbooks/         up / down / seed / debug / reset
scripts/              up.sh down.sh seed.sh contract-check.sh
```

## Stack & versions (design §3)

| Concern | Image | Why this version |
|---|---|---|
| PostgreSQL | `postgres:16-alpine` | no formal LTS; every major supported 5 yrs — 16 until 2028-11 |
| Redis | `redis:7.2-alpine` | no formal LTS; conservative long-supported line |
| Kafka | `confluentinc/cp-kafka:7.9.0` | Kafka 3.9 — Confluent Platform LTS line, KRaft (no ZooKeeper) |
| Nginx | `nginx:1.28-alpine` | stable branch (the LTS-like line) |
| Keycloak | `quay.io/keycloak/keycloak:26.3` | current stable line |

## Docs

- [`docs/architecture/`](docs/architecture) — ADR index and decisions
- [`docs/runbooks/`](docs/runbooks) — operate the stack
- [`AGENTS.md`](AGENTS.md) — conventions + the contract rule for AI-assisted work

## Status

- [x] Infra: compose (base/dev/prod), Nginx gateway, Keycloak realm, Postgres init
- [ ] Contracts: waiting on service detail
- [ ] `backend/` (3 Spring Boot services) and `frontend/` (Vite + React) — separate repos
