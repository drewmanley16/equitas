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

require_cmd cast
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

RPC_URL="${RPC_URL:-$ANVIL_RPC_URL}"

echo "==> Merchant MockUSDC balance BEFORE (atomic units)"
BEFORE_MERCHANT="$(cast call "$USDC_ADDRESS" "balanceOf(address)(uint256)" "$DEMO_MERCHANT_ADDRESS" --rpc-url "$RPC_URL" | awk '{print $1}')"
echo "    $BEFORE_MERCHANT"

echo "==> User status BEFORE (remaining atomic)"
BEFORE_STATUS="$(curl -sfS "http://127.0.0.1:3000/api/benefits/status/$DEMO_USER_ADDRESS")"
echo "$BEFORE_STATUS" | { command -v jq >/dev/null && jq . || cat; }
BEFORE_REM="$(echo "$BEFORE_STATUS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["remainingAtomic"])')"

echo "==> payMerchant as demo user (Anvil account #1) — $DEMO_PAYMENT_ATOMIC atomic (= 10 USDC)"
cast send "$SNAP_SPENDER_ADDRESS" \
  "payMerchant(address,uint256)" \
  "$DEMO_MERCHANT_ADDRESS" \
  "$DEMO_PAYMENT_ATOMIC" \
  --rpc-url "$RPC_URL" \
  --private-key "$ANVIL_ACCOUNT_1_PRIVATE_KEY"

echo "==> Merchant MockUSDC balance AFTER"
AFTER_MERCHANT="$(cast call "$USDC_ADDRESS" "balanceOf(address)(uint256)" "$DEMO_MERCHANT_ADDRESS" --rpc-url "$RPC_URL" | awk '{print $1}')"
echo "    $AFTER_MERCHANT"

echo "==> User status AFTER"
AFTER_STATUS="$(curl -sfS "http://127.0.0.1:3000/api/benefits/status/$DEMO_USER_ADDRESS")"
echo "$AFTER_STATUS" | { command -v jq >/dev/null && jq . || cat; }

AFTER_REM="$(echo "$AFTER_STATUS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["remainingAtomic"])')"

python3 - <<PY
before_m = int("$BEFORE_MERCHANT")
after_m = int("$AFTER_MERCHANT")
pay = int("$DEMO_PAYMENT_ATOMIC")
br = int("$BEFORE_REM")
ar = int("$AFTER_REM")
assert after_m - before_m == pay, "merchant MockUSDC balance delta mismatch"
assert ar == br - pay, "user remaining should drop by payment amount"
print("OK: merchant received", pay, "atomic USDC; user remaining decreased by", pay)
PY
