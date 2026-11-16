# ADR-005: Append-only ledger + ACID balance update as the money source of truth

- **Status:** Accepted (2026-11-16)
- **Context:** Money correctness is the platform's top requirement. Options considered: event-sourced ledger as the only truth (complex reads) vs. a plain mutable balance (no audit trail).
- **Decision:** Money mutations are an **immutable ledger row (append-only) + balance update in one ACID Postgres transaction** (§3, §5.3):
  1. Check idempotency key (unique constraint) — replays return the original result
  2. Lock wallet rows (`SELECT ... FOR UPDATE`, or optimistic locking)
  3. Validate balance — never negative
  4. Insert debit + credit ledger rows
  5. Update both balances
  6. Insert outbox event row; commit
  - Amounts are `BIGINT` minor units (or `NUMERIC(19,4)`). **Never float.**
  - Audit trail on every mutation: actor, timestamp, request id.
  - **Kafka is not the source of truth** — events go out after commit via the outbox.
- **Consequences:**
  - Hot-path transaction ~1–5 ms; no exotic caching needed (§5.3).
  - Full reconciliation is possible from the ledger alone.
  - Redis only caches the read path and is invalidated on write (ADR-007).
