#!/usr/bin/env bash
# Boot the full local stack (design §9). Merges base + overlay, waits for health.
# Usage:
#   scripts/up.sh        # dev overlay (default): debug ports on loopback
#   scripts/up.sh prod   # prod overlay: resource limits, only the gateway exposed
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env"
ENV_EXAMPLE="$ROOT/.env.example"
COMPOSE_DIR="$ROOT/infra/compose"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo ">> created .env from .env.example — review the passwords before real use"
fi

OVERLAY="$COMPOSE_DIR/docker-compose.dev.yml"
MODE="dev"
if [[ "${1:-}" == "prod" ]]; then
  OVERLAY="$COMPOSE_DIR/docker-compose.prod.yml"
  MODE="prod"
fi

COMPOSE=(docker compose --env-file "$ENV_FILE"
  -f "$COMPOSE_DIR/docker-compose.base.yml"
  -f "$OVERLAY")

echo ">> starting stack (mode: $MODE) — waiting for health…"
"${COMPOSE[@]}" up -d --wait --wait-timeout 300

echo
echo ">> stack is up:"
"${COMPOSE[@]}" ps
echo
echo ">> gateway  : http://localhost:8080  (502 on /api/** until services exist)"
echo ">> keycloak : http://localhost:8180"
echo ">> next     : ./scripts/seed.sh   (creates kafka topics)"
