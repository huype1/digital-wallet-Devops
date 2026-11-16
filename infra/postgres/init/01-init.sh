#!/usr/bin/env bash
# Runs ONCE, on first boot of the postgres volume (docker-entrypoint-initdb.d).
# Creates one role + one schema per service (design §3/§4, ADR-003) plus the
# Keycloak store. Table migrations are owned by each service via Flyway —
# this script only bootstraps the isolation boundaries.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
CREATE ROLE user_service   LOGIN PASSWORD '${USER_SERVICE_DB_PASSWORD}';
CREATE ROLE wallet_service LOGIN PASSWORD '${WALLET_SERVICE_DB_PASSWORD}';
CREATE ROLE ledger_service LOGIN PASSWORD '${LEDGER_SERVICE_DB_PASSWORD}';
CREATE ROLE keycloak       LOGIN PASSWORD '${KEYCLOAK_DB_PASSWORD}';

CREATE SCHEMA users    AUTHORIZATION user_service;
CREATE SCHEMA wallet   AUTHORIZATION wallet_service;
CREATE SCHEMA ledger   AUTHORIZATION ledger_service;
CREATE SCHEMA keycloak AUTHORIZATION keycloak;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
EOSQL

echo ">> schemas + roles created: users, wallet, ledger, keycloak"
