# ADR-007: Reject Redis-first / write-behind for money writes; Redis = read path only

- **Status:** Accepted (2026-11-16)
- **Context:** Caching writes in Redis with write-behind flush could shave latency off balance updates. But a crash between the Redis write and the flush **loses money**, and the latency win over an indexed Postgres row update (~1–5 ms) is negligible.
- **Decision:** Redis is **never authoritative for money**. It serves the read path only: balance/account lookups with **invalidate-on-write** (or short TTL), idempotency keys, token blacklist, rate limiting (§3, §5.4). Redis is disposable — a flush must never corrupt anything. Write-behind is acceptable **only for non-authoritative data**: analytics counters, notification fan-out state, sessions.
- **Consequences:**
  - The write path stays exactly one ACID transaction in Postgres (ADR-005).
  - Redis outage degrades performance on reads, never correctness on money.
  - No reconciliation jobs needed between Redis and the ledger.
