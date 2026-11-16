# Digital Wallet Platform — System Design

> Version: 0.2 (observability now in-stack) · Date: 2026-11-17
> Status: Approved for initial build

---

## 1. Overview

A digital wallet platform built as 3 Spring Boot microservices behind an Nginx
API gateway, with Keycloak for authentication, PostgreSQL as the authoritative
store, Kafka for async eventing, and Redis for caching. Observability ships
with the stack: Prometheus (metrics), Grafana (dashboards), OpenTelemetry
(tracing).

Design principles:

1. **Contract-first** — API schemas are the source of truth; both BE and FE are generated/validated against them.
2. **Ledger as single source of truth** — money mutations are append-only and ACID in Postgres. Redis and Kafka are never authoritative for balances.
3. **Logical data isolation** — one Postgres instance, one schema per service, no cross-schema queries. Physical split comes later if ever needed.
4. **Async where possible** — Kafka for inter-service events; sync REST only at the edges that need it.
5. **AI-assisted development** — contracts + steering docs drive code generation in both repos.

---

## 2. Repository & Workspace Layout

Three repos, no service code in the workspace:

```
workspace/                  # orchestration repo (committed to git — infra is code)
├── infra/
│   ├── compose/
│   │   ├── docker-compose.base.yml    # shared defaults (healthchecks, networks)
│   │   ├── docker-compose.dev.yml     # bind mounts, hot reload, mocks
│   │   └── docker-compose.prod.yml    # published images, resource limits
│   ├── nginx/                         # gateway config per env
│   ├── keycloak/                      # realm export (versioned!)
│   └── observability/                 # prometheus, grafana, otel collector configs
├── contracts/                         # openapi.yaml per service + shared enums
├── docs/
│   ├── architecture/                  # diagrams + ADRs (adr-001-*.md)
│   └── runbooks/                      # up/down, seed, debug, reset
├── scripts/
│   ├── up.sh / down.sh
│   ├── seed.sh
│   └── contract-check.sh
├── .env.example
├── AGENTS.md                          # AI steering: contract rule, conventions
└── README.md

backend/                    # one repo, 3 Spring Boot services (multi-module)
frontend/                   # Vite + React SPA
```

- The workspace **is** committed to git; compose/nginx/keycloak-realm changes are reviewed like code.
- Keycloak realm export is versioned so auth config is reproducible.

---

## 3. Tech Stack

| Concern | Choice | Notes |
|---|---|---|
| Language / runtime | Java 21 + Spring Boot 3.x | |
| API gateway | **Nginx** | reverse proxy + LB; static routing |
| Auth | **Keycloak** (OAuth2 / JWT) | services validate JWT via `spring-boot-starter-oauth2-resource-server` |
| Services | 3 × Spring Boot | users, wallet, ledger/notification |
| Database | PostgreSQL 16 | one instance, one schema per service |
| Migrations | Flyway | per service, owned by that service only |
| Messaging | Kafka | domain events after commit (transactional outbox) |
| Cache | Redis | read-path caching, idempotency keys, token blacklist, rate limiting |
| Resilience | Resilience4j | library in services; only on sync call sites |
| Metrics | Micrometer → Prometheus | `/actuator/prometheus` per service; Prometheus also scrapes infra exporters |
| Dashboards | Grafana | datasources + dashboards provisioned as code from `infra/observability/` |
| Tracing | OpenTelemetry (Java agent) | config-only, no code changes; OTLP → OTel Collector → Jaeger (dev) |
| Frontend | Vite + React (SPA) | no SSR needed; React Router or TanStack Router |
| Docs/ADRs | Markdown in `docs/` | one ADR per stack decision |

### Money handling rules (non-negotiable)

- Amounts stored as `BIGINT` minor units (or `NUMERIC(19,4)`). **Never float.**
- Append-only **ledger** table; every mutation = an immutable ledger row + balance update **in the same ACID transaction**.
- `SELECT ... FOR UPDATE` (or optimistic locking) on the wallet row — balance updates serialize.
- **Idempotency keys** on all payment/transfer endpoints.
- Kafka events published **after commit** via the transactional outbox pattern.
- Audit trail on every mutation: actor, timestamp, request id.

---

## 4. Services

| Service | Responsibility | Owns (schema) |
|---|---|---|
| `user-service` | Registration, profiles, KYC status | `users` |
| `wallet-service` | Accounts, balances, transfers, ledger | `wallet` |
| `ledger-service` (or notification) | Event projection, statements, notifications | `ledger` |

- Each service: own Dockerfile, own Flyway migrations, own CI pipeline.
- No service reads another service's schema — ever.

---

## 5. Architecture

### 5.1 High-level flow

```
                      ┌──────────────┐
  Client (Vite+React) │    Nginx     │  /api/users/**  → user-service
  ───────────────────▶│  API gateway │  /api/wallet/** → wallet-service
        HTTPS/JWT     └──────┬───────┘
                             │
                 ┌───────────┼────────────┐
                 ▼           ▼            ▼
           user-service  wallet-service   ledger-service
                 │           │            │
                 ▼           ▼            ▼
               [users]     [wallet]     [ledger]      ← Postgres (1 instance, 3 schemas)
                 │           │            │
                 └───────────┴─────┬──────┘
                                   ▼
                                 Kafka  (domain events, outbox pattern)
                                   │
                                   ▼
                              Redis (read cache / idempotency / blacklist)
```

### 5.2 Sync vs async

- **Sync (REST via gateway)**: client-facing reads/writes, real-time balance check.
- **Async (Kafka)**: domain events (`WalletCredited`, `WalletDebited`, `UserRegistered`), projections into `ledger` schema, notifications.
- Rule: **Kafka is not the source of truth for money** — Postgres ledger is.

### 5.3 Write path (the money transaction)

```
1. Client → POST /api/wallet/transfer (with Idempotency-Key)
2. wallet-service: validate JWT + input
3. In ONE Postgres transaction:
   a. Check idempotency key (unique constraint) — replay returns original result
   b. Lock both wallet rows (SELECT ... FOR UPDATE)
   c. Validate balance (never negative)
   d. INSERT 2 ledger rows (debit + credit)
   e. UPDATE both balances
   f. INSERT outbox event row
   COMMIT
4. Outbox publisher → Kafka topic
5. ledger-service consumes → builds statements/views
6. Redis balance cache invalidated
```

Latency of step 3 is ~1–5 ms; this is the hot path and needs no exotic caching.

### 5.4 Caching strategy (read path only)

- Redis caches balance/account lookups; **invalidate on write** (or short TTL).
- Redis is disposable — a flush must never corrupt anything.
- Write-behind / Redis-first writes are **rejected** (ADR-007): a crash between Redis write and flush loses money, and the latency win is negligible vs an indexed Postgres row update.
- Redis-first/write-behind is acceptable **only for non-authoritative data**: analytics counters, notification fan-out state, sessions.

---

## 6. Auth (Keycloak)

- Keycloak issues JWTs; Nginx passes them through untouched.
- Each service validates locally with `oauth2-resource-server` (stateless, no gateway dependency).
- Redis holds a revocation blacklist (logout / compromised tokens).
- Realm config exported to `infra/keycloak/` and versioned.

---

## 7. Resilience

Layered, minimal on purpose:

| Concern | Mechanism | Where |
|---|---|---|
| Downstream hangs | **Timeouts everywhere** (HTTP client, Redis, DB pool) | all services |
| Sync REST between services | Resilience4j circuit breaker + fallback | call site in consumer service |
| Kafka consumer failures | Retry (few attempts) → **DLQ** | consumers |
| Kafka handler calling a sick dependency | breaker around the sync call inside handler | consumer |
| Fully dead service | Nginx passive health check (`max_fails`, `fail_timeout`) | gateway |
| Postgres down | fail loudly — **no graceful degradation for money ops** | wallet-service |

Decision rule:

- Async flow (Kafka in → DB-only out): **DLQ + timeouts are enough**, no breaker.
- Sync call with a meaningful fallback: add breaker + fallback.
- Order of adoption: **timeouts → retries with backoff → breaker** (only where needed).

Resilience4j is included as a default dependency in all 3 services but expected to have only 1–2 actual breaker configurations system-wide.

---

## 8. AI-Assisted Development Workflow

1. **Change the contract first** (`contracts/openapi-<service>.yaml`).
2. Generate BE handler stubs + FE typed clients from the contract.
3. AI implements against conventions in each repo's `AGENTS.md` / steering docs.
4. Tests: unit per service + **contract tests** (schema vs implementation).
5. Contract tests green = feature done; CI blocks drift.

Steering layering:

- `backend/AGENTS.md` — how to run tests, migration rules, money-handling rules (§3).
- `frontend/AGENTS.md` — component conventions, generated-client usage only.
- `workspace/AGENTS.md` — **the contract rule**: any change to `contracts/` must update both repos in the same change window.

---

## 9. Local Development & Deployment

- `docker compose up` (base + dev overlay) boots: 3 services, Postgres, Kafka, Redis, Nginx, Keycloak, Prometheus, Grafana, OTel Collector + Jaeger UI.
- One command = full stack; each service still runs standalone when needed.
- Environments via `env_file` + `.env.example` committed, real `.env` git-ignored.
- CI per repo: build image → run tests → contract check → publish image.
- Deploy: prod compose overlay (later: k8s manifests if warranted). **No k8s now.**

---

## 10. Observability

In-stack from day one — three pillars, one pipeline:

- **Logs** — structured JSON (`logstash-logback-encoder`); correlation/request IDs propagated gateway → services → Kafka headers; `traceId`/`spanId` stamped into every line via MDC.
- **Metrics** — Micrometer + Prometheus registry: every service exposes `/actuator/prometheus`; Prometheus also scrapes infra exporters (Postgres, Redis, Kafka, Nginx).
- **Traces** — OpenTelemetry Java agent (config only, no code changes): OTLP → OTel Collector → Jaeger (dev backend); W3C trace context propagates through Nginx and into Kafka record headers, so consumers continue the same trace.

Grafana provisions datasources + dashboards as code from `infra/observability/`. v1 dashboards:

- Money-path RED: transfer rate / error ratio / p99 latency; ledger commit time.
- Kafka consumer lag (`ledger-service`) + outbox publisher backlog.
- DB pool saturation, Redis cache hit ratio, JVM + gateway throughput.

Rules:

- Alert rules arrive with prod, but the metric series must exist from v1 — metrics cannot be backfilled.
- Head-based sampling ~10%; the money write path (§5.3) traced at 100%.
- Prometheus/Grafana are read-only views — the ledger (Postgres) remains the only authoritative store.

---

## 11. ADR Index

| ADR | Decision |
|---|---|
| 001 | Nginx over Spring Cloud Gateway (lighter; breakers live in services) |
| 002 | Keycloak over hand-rolled auth |
| 003 | One Postgres instance, schema-per-service (physical split later if needed) |
| 004 | Kafka over Redis Streams for domain events |
| 005 | Ledger (append-only) + ACID balance update as money source of truth |
| 006 | Vite + React SPA over Next.js (no SSR/SEO need) |
| 007 | Reject Redis-first/write-behind for money writes; Redis = read path only |
| 008 | Resilience4j in services, not at the gateway edge |
| 009 | Prometheus + Grafana + OpenTelemetry in-stack from day one (agent-based tracing, dashboards as code) |

---

## 12. Known Trade-offs / Future Work

- Single Postgres instance = single point of failure → add managed DB / streaming replica before production.
- No distributed transactions across services → deliberately avoided; keep money ops inside one service boundary. Revisit sagas only if a real cross-service ACID need appears.
- Keycloak ops overhead accepted (~1 GB RAM).
- SCG swap-in remains possible if edge-level breakers/custom filters become necessary.
