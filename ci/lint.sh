#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

issues=0
detail=""
skipped=""

if command -v selene >/dev/null 2>&1; then
  if ! out=$(selene src 2>&1); then
    issues=$((issues + 1))
    detail="${detail}selene: $(echo "$out" | tr '\n' ' ' | sed 's/"/\\"/g');"
  fi
else
  skipped="${skipped}selene not on PATH;"
fi

if command -v stylua >/dev/null 2>&1; then
  if ! out=$(stylua --check src 2>&1); then
    issues=$((issues + 1))
    detail="${detail}stylua: $(echo "$out" | tr '\n' ' ' | sed 's/"/\\"/g');"
  fi
else
  skipped="${skipped}stylua not on PATH;"
fi

if [ "$issues" -gt 0 ]; then
  echo "{\"status\":\"TESTS_FAILED\",\"advisory\":true,\"issues\":$issues,\"detail\":\"$detail\",\"skipped\":\"$skipped\"}"
  exit 0
fi

if [ -n "$skipped" ]; then
  echo "{\"status\":\"NO_TESTS\",\"advisory\":true,\"reason\":\"no lint tools available\",\"skipped\":\"$skipped\"}"
  exit 0
fi

echo '{"status":"PASSED","advisory":true}'
