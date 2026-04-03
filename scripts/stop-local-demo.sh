#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCALD="$REPO_ROOT/.local-demo"

CLEAN=0
for arg in "$@"; do
  if [[ "$arg" == "--clean" ]]; then
    CLEAN=1
  fi
done

stop_pidfile() {
  local f="$1"
  local name="$2"
  if [[ ! -f "$f" ]]; then
    return 0
  fi
  local pid
  pid="$(cat "$f" || true)"
  if [[ -z "$pid" ]]; then
    rm -f "$f"
    return 0
  fi
  if kill -0 "$pid" 2>/dev/null; then
    echo "==> Stopping $name (PID $pid)"
    kill "$pid" 2>/dev/null || true
    sleep 0.3
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  else
    echo "==> Stale PID file for $name (process not running): $f"
  fi
  rm -f "$f"
}

stop_pidfile "$LOCALD/backend.pid" "backend"
stop_pidfile "$LOCALD/anvil.pid" "anvil"

if [[ "$CLEAN" -eq 1 ]]; then
  echo "==> Removing $LOCALD (--clean)"
  rm -rf "$LOCALD"
else
  echo "==> Kept deployment artifacts under $LOCALD (use --clean to delete)"
fi

echo "Done."
