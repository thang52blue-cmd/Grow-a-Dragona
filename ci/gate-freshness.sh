#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CACHE_DIR="$ROOT_DIR/.ci-cache"
STAMP_FILE="$CACHE_DIR/last-green.json"

current_signature() {
  local head dirty
  head=$(git rev-parse HEAD 2>/dev/null || echo "no-commit")
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    dirty="dirty"
  else
    dirty="clean"
  fi
  echo "${head}:${dirty}"
}

if [ "${1:-}" = "--stamp" ]; then
  mkdir -p "$CACHE_DIR"
  sig=$(current_signature)
  printf '{"signature":"%s"}\n' "$sig" >"$STAMP_FILE"
  echo "{\"status\":\"STAMPED\",\"signature\":\"$sig\"}"
  exit 0
fi

if [ ! -f "$STAMP_FILE" ]; then
  echo '{"status":"STALE","reason":"no stamp file yet"}'
  exit 0
fi

sig=$(current_signature)
stamped_sig=$(sed -n 's/.*"signature":"\([^"]*\)".*/\1/p' "$STAMP_FILE")

if [ "$sig" = "$stamped_sig" ]; then
  echo "{\"status\":\"FRESH\",\"signature\":\"$sig\"}"
else
  echo "{\"status\":\"STALE\",\"signature\":\"$sig\"}"
fi
