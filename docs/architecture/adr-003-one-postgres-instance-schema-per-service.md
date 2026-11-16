# ADR-003: One Postgres instance, one schema per service

- **Status:** Accepted (2026-11-16)
- **Context:** Three services need durable storage. Physical DB-per-service gives hard isolation but adds real operational burden from day one.
- **Decision:** One PostgreSQL instance; one database (`wallet_platform`); **one schema per service** — `users`, `wallet`, `ledger` — plus a `keycloak` schema. Each service gets its own role owning only its schema. **No cross-schema queries — ever.** Flyway migrations are owned per service; `infra/postgres/init` only creates the boundaries (design §3/§4).
- **Consequences:**
  - Single Postgres instance = single point of failure → add a managed DB / streaming replica before production (§12).
  - Logical isolation keeps the option open: physical split later if ever needed, since schemas make lift-out tractable.
  - Service roles enforce the boundary at the database level, not just by convention.
