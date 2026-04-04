#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=arc-local-constants.sh
source "$SCRIPT_DIR/arc-local-constants.sh"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1"
    exit 1
  fi
}

require_cmd curl

CONTRACTS_ENV="$REPO_ROOT/.local-demo/contracts.env"
if [[ ! -f "$CONTRACTS_ENV" ]]; then
  echo "ERROR: $CONTRACTS_ENV missing — run deploy-local-contracts.sh first."
  exit 1
fi

# shellcheck source=/dev/null
set -a
source "$CONTRACTS_ENV"
set +a

BASE_URL="${BASE_URL:-http://127.0.0.1:3000}"

pretty() {
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    cat
  fi
}

echo "==> GET /api/health"
curl -sfS "$BASE_URL/api/health" | pretty
echo ""

echo "==> POST /api/benefits/approve-user (demo user allowance)"
curl -sfS "$BASE_URL/api/benefits/approve-user" \
  -H 'Content-Type: application/json' \
  -d "{\"userAddress\":\"$DEMO_USER_ADDRESS\",\"allowanceAtomic\":\"$DEMO_USER_ALLOWANCE_ATOMIC\"}" | pretty
echo ""

echo "==> POST /api/benefits/setup-merchant"
curl -sfS "$BASE_URL/api/benefits/setup-merchant" \
  -H 'Content-Type: application/json' \
  -d "{\"merchantAddress\":\"$DEMO_MERCHANT_ADDRESS\",\"approved\":true}" | pretty
echo ""

echo "==> POST /api/benefits/deposit"
curl -sfS "$BASE_URL/api/benefits/deposit" \
  -H 'Content-Type: application/json' \
  -d "{\"amountAtomic\":\"$DEMO_DEPOSIT_ATOMIC\"}" | pretty
echo ""

echo "==> GET /api/benefits/status/:userAddress"
curl -sfS "$BASE_URL/api/benefits/status/$DEMO_USER_ADDRESS" | pretty
echo ""

echo "OK: all API steps returned HTTP 2xx"
