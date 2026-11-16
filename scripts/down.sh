#!/usr/bin/env bash
# Stop the stack. Keeps data volumes by default; pass -v to wipe them (docs/runbooks/down.md).
# Usage:
#   scripts/down.sh          # stop, keep data
#   scripts/down.sh -v       # stop AND wipe all data volumes (local dev only!)
#   scripts/down.sh --prod   # tear down the prod overlay instead of dev
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env"
COMPOSE_DIR="$ROOT/infra/compose"

OVERLAY="$COMPOSE_DIR/docker-compose.dev.yml"
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --prod) OVERLAY="$COMPOSE_DIR/docker-compose.prod.yml" ;;
    *) ARGS+=("$arg") ;;
  esac
done

docker compose --env-file "$ENV_FILE" \
  -f "$COMPOSE_DIR/docker-compose.base.yml" \
  -f "$OVERLAY" down "${ARGS[@]}" --remove-orphans
