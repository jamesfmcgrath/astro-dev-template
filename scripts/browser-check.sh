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
SERVER_STARTED=0

# "astro preview stop", not "kill", because Astro 7's preview server is a
# detached daemon: the command starts it, prints its address and exits, so the
# shell never has a PID that owns it. Killing the pnpm wrapper (what this
# script used to do) left the server running and holding the port. Observed
# live on 2026-09-10 with astro 7.3.2.
cleanup() {
  if [ "$SERVER_STARTED" = "1" ]; then
    pnpm astro preview stop >/dev/null 2>&1 || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT INT TERM

# A server already on the port is fatal rather than tolerated: astro preview
# silently falls back to the next free port (4322) when 4321 is taken, and the
# readiness check below would then pass against whatever the other server is
# serving, scanning a stale build with no warning.
if curl -sSf "$BASE_URL/" >/dev/null 2>&1; then
  die "Something is already serving $BASE_URL. Most likely a 'make dev' or a 'make preview' left running: stop 'make dev' with Ctrl-C, or if it is a leftover preview server run 'pnpm astro preview stop'. Then re-run."
fi

info "Building the production site (astro build)..."
pnpm astro build

info "Starting the preview server ($BASE_URL)..."
# Set before the call, not after: --background means the server can be up even
# when the command that started it reports a failure, and the trap has to know.
SERVER_STARTED=1
pnpm astro preview --background --port 4321 >"$LOG_FILE" 2>&1 || {
  cat "$LOG_FILE" >&2
  die "Could not start the preview server."
}

# Assert the port from what the server itself reported, not from a probe.
# astro preview falls back to the next free port without failing, so a curl
# against 4321 proves only that something answers there, which is exactly the
# stale-build trap the pre-flight above is trying to close: a server that was
# not yet answering at pre-flight time but is by now would take 4321, push
# this run's server to 4322, and satisfy the readiness loop below.
ACTUAL_URL="$(grep -o 'http://localhost:[0-9]\{1,\}' "$LOG_FILE" | head -n 1 || true)"
if [ -z "$ACTUAL_URL" ]; then
  cat "$LOG_FILE" >&2
  die "Could not read the preview server's address from its output."
fi
if [ "$ACTUAL_URL" != "$BASE_URL" ]; then
  die "The preview server started on $ACTUAL_URL, not $BASE_URL: something else took the port. Stop it, then re-run."
fi

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
