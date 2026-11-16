# Architecture Decision Records

One ADR per stack decision (design §3). New decisions get the next number and
an entry here.

| ADR | Decision | File |
|---|---|---|
| 001 | Nginx over Spring Cloud Gateway (lighter; breakers live in services) | [adr-001](adr-001-nginx-over-spring-cloud-gateway.md) |
| 002 | Keycloak over hand-rolled auth | [adr-002](adr-002-keycloak-over-hand-rolled-auth.md) |
| 003 | One Postgres instance, schema-per-service (physical split later if needed) | [adr-003](adr-003-one-postgres-instance-schema-per-service.md) |
| 004 | Kafka over Redis Streams for domain events | [adr-004](adr-004-kafka-over-redis-streams-for-domain-events.md) |
| 005 | Ledger (append-only) + ACID balance update as money source of truth | [adr-005](adr-005-ledger-append-only-money-source-of-truth.md) |
| 006 | Vite + React SPA over Next.js (no SSR/SEO need) | [adr-006](adr-006-vite-react-spa-over-nextjs.md) |
| 007 | Reject Redis-first/write-behind for money writes; Redis = read path only | [adr-007](adr-007-reject-redis-first-writes-for-money.md) |
| 008 | Resilience4j in services, not at the gateway edge | [adr-008](adr-008-resilience4j-in-services-not-gateway.md) |
