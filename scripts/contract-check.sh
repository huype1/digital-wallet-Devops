#!/usr/bin/env bash
# Validate API contracts — the contract-first CI gate (design §8).
# No contracts exist yet: exits 0 with a notice so CI stays green.
# Once contracts/openapi-<service>.yaml files land they are linted here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shopt -s nullglob
files=(contracts/*.yaml contracts/*.yml)

if (( ${#files[@]} == 0 )); then
  echo ">> no contracts yet (contracts/ is empty) — nothing to check"
  echo ">> reminder: any change to contracts/ must update backend/ and frontend/ in the same change window"
  exit 0
fi

can_validate=0
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  can_validate=1
fi

status=0
for f in "${files[@]}"; do
  if (( can_validate )); then
    if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
      echo ">> OK   $f"
    else
      echo ">> FAIL $f (invalid YAML)"
      status=1
    fi
  else
    echo ">> SKIP $f (python3 + PyYAML not available for syntax check)"
  fi
done

echo ">> TODO: wire @redocly/cli lint (or spectral) for full OpenAPI validation once contracts exist"
exit "$status"
