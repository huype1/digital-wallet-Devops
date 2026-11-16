# ADR-008: Resilience4j in services, not at the gateway edge

- **Status:** Accepted (2026-11-16)
- **Context:** The platform needs resilience against downstream hangs, sync call-site failures, and Kafka consumer failures. Putting breakers at the gateway edge would require a programmable gateway (Spring Cloud Gateway) and duplicates concerns.
- **Decision:** Layered, minimal on purpose (§7):
  - **Timeouts everywhere** — HTTP clients, Redis, DB pool (all services).
  - **Sync REST between services** → Resilience4j circuit breaker + fallback at the call site in the consumer service.
  - **Kafka consumer failures** → retry (few attempts) → DLQ.
  - **Fully dead service** → Nginx passive health check (`max_fails`, `fail_timeout`) — ADR-001.
  - **Postgres down** → fail loudly; **no graceful degradation for money ops**.
  - Adoption order: **timeouts → retries with backoff → breaker**, only where a meaningful fallback exists. Async flow (Kafka in → DB-only out): DLQ + timeouts are enough, no breaker.
- **Consequences:**
  - Resilience4j is a default dependency in all 3 services but is expected to have only 1–2 actual breaker configurations system-wide.
  - The gateway stays dumb (ADR-001); a SCG swap-in would only be needed if edge-level resilience were ever justified.
