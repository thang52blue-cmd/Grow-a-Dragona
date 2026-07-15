#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LANE="${1:-fast}"

if [ "$LANE" = "engine" ]; then
  echo '{"status":"NO_TESTS","reason":"engine lane deferred until activation ADR (backlog #3)"}'
  exit 0
fi

if [ "$LANE" != "fast" ]; then
  echo "{\"status\":\"COMPILE_ERROR\",\"reason\":\"unknown lane: $LANE\"}"
  exit 1
fi

if ! command -v lune >/dev/null 2>&1; then
  echo '{"status":"NO_TESTS","reason":"lune not found on PATH; run: rokit install"}'
  exit 1
fi

mapfile -t spec_files < <(find src -name '*.spec.luau' 2>/dev/null | sort)

if [ "${#spec_files[@]}" -eq 0 ]; then
  echo '{"status":"NO_TESTS","reason":"no *.spec.luau files found under src/"}'
  exit 0
fi

failed=0
failed_specs=()
for spec in "${spec_files[@]}"; do
  if ! lune run "$spec" >/dev/null 2>&1; then
    failed=$((failed + 1))
    failed_specs+=("$spec")
  fi
done

if [ "$failed" -gt 0 ]; then
  joined=$(printf '%s,' "${failed_specs[@]}")
  echo "{\"status\":\"TESTS_FAILED\",\"specCount\":${#spec_files[@]},\"failedCount\":$failed,\"failed\":\"${joined%,}\"}"
  exit 1
fi

echo "{\"status\":\"PASSED\",\"specCount\":${#spec_files[@]}}"
