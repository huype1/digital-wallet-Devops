# Keycloak realm config (versioned — design §6)

`wallet-realm.json` is a Keycloak realm export, kept in git so auth config is
reproducible. It is mounted into the container and imported automatically
(`start-dev --import-realm`); import is skipped if the realm already exists in
the database.

## What's in the placeholder realm

- realm `wallet`, login/registration settings, short-lived access tokens (15 min), refresh token rotation
- realm roles `user` and `admin`
- one local dev user `local-admin` / `local-admin` (temporary password — Keycloak forces a change on first login)

## Workflow

- **Change realm config in the Keycloak admin console** (http://localhost:8180), then re-export and commit:
  `kc.sh export --dir /opt/keycloak/data/import --realm wallet` (or via the admin CLI), replace `wallet-realm.json`.
- **Reset realm**: `./scripts/down.sh -v` wipes Postgres — next `up.sh` re-imports from this file.
- **OIDC clients for the services** are added here when the service contracts
  land — client IDs should follow the service names (`user-service`, ...).
