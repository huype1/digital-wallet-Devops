# Contracts (API-first — design §8)

The OpenAPI specs are the source of truth for every service API; both
`backend/` and `frontend/` are generated/validated against them.

**No contract files yet** — service endpoints are not designed. Do not invent
them here. Once detail exists, add one file per service:

```
contracts/
├── openapi-users.yaml    # user-service: registration, profiles, KYC status
├── openapi-wallet.yaml   # wallet-service: accounts, balances, transfers, ledger
├── openapi-ledger.yaml   # ledger-service: statements, notifications
└── enums/                # shared enums (e.g. currency, KYC status)
```

## Rules

- Naming: `openapi-<service>.yaml` (§8).
- **The contract rule**: any change to `contracts/` must update `backend/` and
  `frontend/` in the same change window (§8, `AGENTS.md`).
- Money amounts in contracts are strings of integer minor units — never floats (§3).
- Validation runs in `scripts/contract-check.sh`; CI blocks drift.
