#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=arc-local-constants.sh
source "$SCRIPT_DIR/arc-local-constants.sh"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1"
    echo "Install Foundry (forge, cast, anvil): https://book.getfoundry.sh/getting-started/installation"
    exit 1
  fi
}

for c in forge cast curl node npm anvil python3; do
  require_cmd "$c"
done

mkdir -p "$REPO_ROOT/.local-demo"

echo "==> Stopping previous backend from this repo (if PID file exists)"
if [[ -f "$REPO_ROOT/.local-demo/backend.pid" ]]; then
  old="$(cat "$REPO_ROOT/.local-demo/backend.pid" || true)"
  if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
    echo "    killing PID $old"
    kill "$old" 2>/dev/null || true
    sleep 0.5
  fi
  rm -f "$REPO_ROOT/.local-demo/backend.pid"
fi

WE_STARTED_ANVIL=0
if ! curl -sf -X POST "$ANVIL_RPC_URL" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","id":1}' >/dev/null; then
  echo "==> Starting Anvil on $ANVIL_RPC_URL (background)"
  anvil --host 127.0.0.1 --port 8545 >>"$REPO_ROOT/.local-demo/anvil.log" 2>&1 &
  echo $! >"$REPO_ROOT/.local-demo/anvil.pid"
  WE_STARTED_ANVIL=1
  echo "    PID $(cat "$REPO_ROOT/.local-demo/anvil.pid") — log: .local-demo/anvil.log"
  for _ in $(seq 1 80); do
    if curl -sf -X POST "$ANVIL_RPC_URL" -H 'Content-Type: application/json' \
      -d '{"jsonrpc":"2.0","method":"eth_chainId","id":1}' >/dev/null; then
      echo "    Anvil is up."
      break
    fi
    sleep 0.15
  done
  if ! curl -sf -X POST "$ANVIL_RPC_URL" -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","id":1}' >/dev/null; then
    echo "ERROR: Anvil did not become ready in time."
    exit 1
  fi
else
  echo "==> Anvil already responding at $ANVIL_RPC_URL (not starting a new one)"
fi

echo "==> Deploy contracts"
"$SCRIPT_DIR/deploy-local-contracts.sh"

# shellcheck source=/dev/null
set -a
source "$REPO_ROOT/.local-demo/contracts.env"
set +a

echo "==> Mint MockUSDC to admin ($DEMO_MINT_ADMIN_ATOMIC atomic = 1000 USDC)"
cast send "$USDC_ADDRESS" "mint(address,uint256)" "$ANVIL_ACCOUNT_0_ADDRESS" "$DEMO_MINT_ADMIN_ATOMIC" \
  --rpc-url "$ANVIL_RPC_URL" \
  --private-key "$ANVIL_ACCOUNT_0_PRIVATE_KEY"

echo "==> Start backend"
"$SCRIPT_DIR/run-local-backend.sh"

sleep 0.4

echo "==> Wait for http://127.0.0.1:3000/api/health"
for _ in $(seq 1 80); do
  if curl -sfS "http://127.0.0.1:3000/api/health" >/dev/null; then
    echo "    Backend healthy."
    break
  fi
  sleep 0.2
done
if ! curl -sfS "http://127.0.0.1:3000/api/health" >/dev/null; then
  echo "ERROR: backend did not respond on port 3000. See .local-demo/backend.log"
  exit 1
fi

echo "==> Wait for benefits routes (ethers loads after listen)"
READY=0
for _ in $(seq 1 80); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3000/api/benefits/status/0x0000000000000000000000000000000000000001" || echo "000")
  if [[ "$code" != "404" ]]; then
    echo "    Benefits routes ready (HTTP $code)."
    READY=1
    break
  fi
  sleep 0.15
done
if [[ "$READY" != "1" ]]; then
  echo "ERROR: benefits routes did not register. See .local-demo/backend.log"
  exit 1
fi

echo "==> API flow (approve user, merchant, deposit, status)"
BASE_URL=http://127.0.0.1:3000 "$SCRIPT_DIR/test-local-api.sh"

echo "==> On-chain payment (cast payMerchant as user #1)"
"$SCRIPT_DIR/test-local-payment.sh"

echo ""
echo "================== LOCAL ARC DEMO — SUMMARY =================="
echo "Anvil RPC:           $ANVIL_RPC_URL"
echo "Backend:             http://127.0.0.1:3000"
echo "MockUSDC:            $USDC_ADDRESS"
echo "SNAPSpender:         $SNAP_SPENDER_ADDRESS"
echo "Admin (operator):    $ANVIL_ACCOUNT_0_ADDRESS"
echo "Demo user (#1):      $DEMO_USER_ADDRESS"
echo "Demo merchant (#2):  $DEMO_MERCHANT_ADDRESS"
echo "User allowance cap:  $DEMO_USER_ALLOWANCE_ATOMIC atomic (500 USDC)"
echo "Deposit to contract: $DEMO_DEPOSIT_ATOMIC atomic (50 USDC)"
echo "Sample payment:      $DEMO_PAYMENT_ATOMIC atomic (10 USDC)"
echo "Anvil started here:  $([ "$WE_STARTED_ANVIL" = 1 ] && echo yes || echo no)"
echo "============================================================"

echo "==> Final validation (eligibility, merchant approval, balances)"
RPCV="$ANVIL_RPC_URL"
SP="$SNAP_SPENDER_ADDRESS"
US="$USDC_ADDRESS"
U="$DEMO_USER_ADDRESS"
M="$DEMO_MERCHANT_ADDRESS"
PAY="$DEMO_PAYMENT_ATOMIC"
CAP="$DEMO_USER_ALLOWANCE_ATOMIC"

EU="$(cast call "$SP" "approvedUsers(address)(bool)" "$U" --rpc-url "$RPCV" | tr '[:upper:]' '[:lower:]')"
[[ "$EU" == *"true"* ]] || { echo "FAIL: user not eligible"; exit 1; }

EM="$(cast call "$SP" "approvedMerchants(address)(bool)" "$M" --rpc-url "$RPCV" | tr '[:upper:]' '[:lower:]')"
[[ "$EM" == *"true"* ]] || { echo "FAIL: merchant not approved"; exit 1; }

SPENT="$(cast call "$SP" "userSpent(address)(uint256)" "$U" --rpc-url "$RPCV" | awk '{print $1}')"
[[ "$SPENT" == "$PAY" ]] || { echo "FAIL: userSpent ($SPENT) != payment ($PAY)"; exit 1; }

ALLOWANCE="$(cast call "$SP" "userAllowance(address)(uint256)" "$U" --rpc-url "$RPCV" | awk '{print $1}')"
python3 -c "a=int('$ALLOWANCE'); s=int('$SPENT'); cap=int('$CAP'); p=int('$PAY'); assert a==cap; assert a-s==cap-p"

echo "    user allowance (cap): $ALLOWANCE atomic"
echo "    user spent:           $SPENT atomic"
echo "    remaining (cap−spent): $(python3 -c "print(int('$ALLOWANCE')-int('$SPENT'))") atomic"

MB="$(cast call "$US" "balanceOf(address)(uint256)" "$M" --rpc-url "$RPCV" | awk '{print $1}')"
python3 -c "import sys; assert int('$MB') >= int('$PAY'); print('OK: merchant MockUSDC balance covers payment')"
echo "OK: validations passed — ARC local flow complete."

echo ""
echo "Stop with: ./scripts/stop-local-demo.sh"
