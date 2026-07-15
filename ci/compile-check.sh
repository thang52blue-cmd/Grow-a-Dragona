#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if ! command -v rojo >/dev/null 2>&1; then
  echo '{"status":"COMPILE_ERROR","reason":"rojo not found on PATH; run: rokit install"}'
  exit 1
fi

if ! rojo build default.project.json -o "$WORK_DIR/build.rbxlx" >"$WORK_DIR/build.log" 2>&1; then
  detail=$(tail -c 1500 "$WORK_DIR/build.log" | tr '\n' ' ' | sed 's/"/\\"/g')
  echo "{\"status\":\"COMPILE_ERROR\",\"stage\":\"rojo build\",\"detail\":\"$detail\"}"
  exit 1
fi

if ! command -v luau-lsp >/dev/null 2>&1; then
  echo '{"status":"COMPILE_ERROR","reason":"luau-lsp not found on PATH; run: rokit install"}'
  exit 1
fi

if ! rojo sourcemap default.project.json --output "$WORK_DIR/sourcemap.json" >"$WORK_DIR/sourcemap.log" 2>&1; then
  detail=$(tail -c 1500 "$WORK_DIR/sourcemap.log" | tr '\n' ' ' | sed 's/"/\\"/g')
  echo "{\"status\":\"COMPILE_ERROR\",\"stage\":\"rojo sourcemap\",\"detail\":\"$detail\"}"
  exit 1
fi

if ! luau-lsp analyze --sourcemap="$WORK_DIR/sourcemap.json" \
  --definitions="@roblox=$ROOT_DIR/ci/luau-lsp/globalTypes.d.luau" \
  --ignore '**/*.spec.luau' src >"$WORK_DIR/analyze.log" 2>&1; then
  detail=$(tail -c 1500 "$WORK_DIR/analyze.log" | tr '\n' ' ' | sed 's/"/\\"/g')
  echo "{\"status\":\"COMPILE_ERROR\",\"stage\":\"luau-lsp analyze\",\"detail\":\"$detail\"}"
  exit 1
fi

echo '{"status":"COMPILE_OK"}'
