# ADR-004: Kafka over Redis Streams for domain events

- **Status:** Accepted (2026-11-16)
- **Context:** Services need async domain events (`UserRegistered`, `WalletCredited`, `WalletDebited`) for projections, statements and notifications (§5.2). Redis Streams are lighter, but Kafka has stronger ecosystem support for consumer groups, retention, replay and DLQ patterns.
- **Decision:** Use **Kafka** (KRaft mode, no ZooKeeper) for inter-service events. Domain events are published **after commit** via the **transactional outbox** pattern — Kafka is never the source of truth for money (§3, §5.3).
- **Consequences:**
  - Kafka ops overhead (one broker in dev; cluster before real scale).
  - Topics are code: auto-create stays off; `<service>-events` + `<service>-events.dlq` created by `scripts/seed.sh`.
  - Consumer failures: retry → DLQ (§7).
