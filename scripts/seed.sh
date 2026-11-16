#!/usr/bin/env bash
# Seed the local stack.
# Now:      create Kafka topics as code — auto-create stays off (design §3).
# Later:    demo users / wallets / transfers via the gateway API, once service
#           contracts land (design §8).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env"
COMPOSE_DIR="$ROOT/infra/compose"

COMPOSE=(docker compose --env-file "$ENV_FILE"
  -f "$COMPOSE_DIR/docker-compose.base.yml"
  -f "$COMPOSE_DIR/docker-compose.dev.yml")

TOPICS=(
  "user-events"   "user-events.dlq"
  "wallet-events" "wallet-events.dlq"
)

echo ">> creating kafka topics (3 partitions, RF 1 — single-broker dev)"
for topic in "${TOPICS[@]}"; do
  "${COMPOSE[@]}" exec -T kafka kafka-topics \
    --bootstrap-server localhost:9092 \
    --create --if-not-exists \
    --topic "$topic" \
    --partitions 3 \
    --replication-factor 1
done

echo ">> topics now:"
"${COMPOSE[@]}" exec -T kafka kafka-topics --bootstrap-server localhost:9092 --list

echo ">> note: demo-data seeding is not implemented yet — waiting on service contracts"
