#!/usr/bin/env bash
# Build the production site, serve it with "astro preview", run the
# requested browser check against it, then always stop the server.
# Usage: ./scripts/browser-check.sh <a11y|vrt> [extra playwright args]
# Called by "make a11y", "make vrt" and "make vrt-update". Mirrors what the
# "browser" CI job does against the same build; CI inlines its own steps
# instead of calling this script, because it runs both checks against one
# server and needs CI-only baseline/artifact handling this script does not.
# Portable across macOS (BSD) and Linux (GNU); see CONVENTIONS.md's script
# contract.
set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; RESET="\033[0m"
info() { echo -e "${BOLD}> $*${RESET}"; }
ok()   { echo -e "${GREEN}OK $*${RESET}"; }
die()  { echo -e "${RED}xx $*${RESET}" >&2; exit 1; }

CHECK="${1:-}"
case "$CHECK" in
  a11y|vrt) ;;
  *) die "Usage: $0 <a11y|vrt> [extra playwright args]" ;;
esac
shift

BASE_URL="http://localhost:4321"
LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/astro-preview-log.XXXXXX")"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

info "Building the production site (astro build)..."
pnpm astro build

info "Starting the preview server ($BASE_URL)..."
pnpm astro preview --port 4321 >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

ready=false
i=1
while [ "$i" -le 30 ]; do
  if curl -sSf "$BASE_URL/" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
  i=$((i + 1))
done

if [ "$ready" != "true" ]; then
  echo "astro preview did not respond on $BASE_URL." >&2
  cat "$LOG_FILE" >&2
  exit 1
fi
ok "Preview server ready."

case "$CHECK" in
  a11y)
    info "Running the accessibility scan (axe-core)..."
    node scripts/a11y-scan.mjs --base-url="$BASE_URL"
    ;;
  vrt)
    info "Running the visual regression test..."
    VRT_BASE_URL="$BASE_URL" pnpm exec playwright test tests/vrt "$@"
    ;;
esac
