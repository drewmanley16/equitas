# Local ARC demo (100% localhost — safe)

This workflow runs the Equitas **ARC programmable USDC** path entirely on your machine:

- **Anvil** only (`127.0.0.1:8545`) — not mainnet, not public testnets  
- **MockUSDC** only — no real USDC  
- **No MetaMask** — keys are the **default Anvil accounts** (public, disposable, localhost-only)  
- **No real money** — all balances are fictional chain state  

Private keys in `scripts/arc-local-constants.sh` are the **standard Anvil defaults** (account #0–#2). They are **never** safe to use on any real network. The scripts never ask you to paste or export a key.

---

## Requirements

| Tool | Purpose |
|------|---------|
| [Foundry](https://book.getfoundry.sh/getting-started/installation) | `forge`, `cast`, `anvil` |
| Node.js + npm | backend |
| `curl` | HTTP checks |
| `python3` | JSON / bigint checks (macOS/Linux have this) |
| `jq` | optional; nicer JSON in logs |

One-time contract dependencies:

```bash
cd blockchain
./install-deps.sh
```

---

## One-command full demo

From the **repository root**:

```bash
chmod +x scripts/*.sh
./scripts/run-local-arc-demo.sh
```

**What it does**

1. Stops a previous backend PID recorded under `.local-demo/backend.pid` (if any).  
2. Starts **Anvil** in the background **only if** nothing responds on `http://127.0.0.1:8545`; stores PID in `.local-demo/anvil.pid`.  
3. Runs `deploy-local-contracts.sh` → writes `.local-demo/contracts.env`.  
4. Mints **1000** MockUSDC (6 decimals) to the admin account.  
5. Runs `run-local-backend.sh` → writes `backend/.env` with **Anvil #0** as operator; starts Node; PID in `.local-demo/backend.pid`.  
6. Waits until `GET http://127.0.0.1:3000/api/health` succeeds.  
7. Runs `test-local-api.sh` (approve user, merchant, deposit, status).  
8. Runs `test-local-payment.sh` (`cast payMerchant` as Anvil #1).  
9. Prints a summary and runs on-chain checks.

**Expected success:** script exits `0`; final lines include `OK: validations passed`.

**Stop processes**

```bash
./scripts/stop-local-demo.sh
```

Remove artifacts (optional):

```bash
./scripts/stop-local-demo.sh --clean
```

---

## Commands (granular)

| Goal | Command |
|------|---------|
| Full demo | `./scripts/run-local-arc-demo.sh` |
| Deploy only (Anvil must be up) | `./scripts/deploy-local-contracts.sh` |
| Backend only (needs `.local-demo/contracts.env`) | `./scripts/run-local-backend.sh` |
| API test only (backend on `:3000`) | `./scripts/test-local-api.sh` |
| Payment test only (Anvil + contracts + API state from prior steps) | `./scripts/test-local-payment.sh` |
| Stop | `./scripts/stop-local-demo.sh` |

Environment overrides:

- `BASE_URL` — for `test-local-api.sh` (default `http://127.0.0.1:3000`)  
- `ANVIL_RPC_URL` — default `http://127.0.0.1:8545`  

---

## Default Anvil accounts (disposable)

| Role | Address |
|------|---------|
| #0 Admin / backend operator | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| #1 Demo user (`payMerchant`) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` |
| #2 Demo merchant | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` |

Keys are defined only in `scripts/arc-local-constants.sh` for automation.

---

## Demo amounts (6 decimals)

| Step | Atomic | USDC |
|------|--------|------|
| Mint to admin | `1000000000` | 1000 |
| User allowance cap | `500000000` | 500 |
| Deposit into `SNAPSpender` | `50000000` | 50 |
| Sample payment | `10000000` | 10 |

---

## Files produced

| Path | Content |
|------|---------|
| `.local-demo/contracts.env` | `SNAP_SPENDER_ADDRESS`, `USDC_ADDRESS`, `ADMIN_ADDRESS`, RPC, demo addresses |
| `.local-demo/anvil.pid` | PID if this demo started Anvil |
| `.local-demo/backend.pid` | PID of Node backend |
| `.local-demo/anvil.log` | Anvil stdout/stderr |
| `.local-demo/backend.log` | Backend stdout/stderr |
| `.local-demo/last-deploy.log` | Last `forge script` log |
| `backend/.env` | Generated local operator config (**do not commit**) |

Template for humans: `backend/.env.local.example`.

---

## Common failures

| Symptom | Fix |
|---------|-----|
| `forge-std` / OpenZeppelin missing | `cd blockchain && ./install-deps.sh` |
| `Port 3000 already in use` | Stop old backend: `./scripts/stop-local-demo.sh` or kill the process using port 3000 |
| Anvil already running with **wrong chain state** | `./scripts/stop-local-demo.sh --clean` and restart Anvil, or restart machine |
| `could not find broadcast run-latest.json` | Re-run deploy; ensure Anvil is on chain id **31337** (default) |
| Backend 500 on `/api/benefits/*` | Check `backend/.env` addresses match `.local-demo/contracts.env`; read `.local-demo/backend.log` |

---

## Assumptions (this repo)

- Contracts: `MockUSDC`, `SNAPSpender` deployed via `blockchain/script/Deploy.s.sol` (`DeployScript`).  
- Broadcast JSON path: `blockchain/broadcast/Deploy.s.sol/31337/run-latest.json` (Anvil).  
- Backend: `backend/src/index.js`, `GET /api/health`, benefits routes under `/api/benefits/`.  
- Default backend port: **3000** (override with `PORT` in `backend/.env`).  

This path **does not** use the iOS app or Xcode.
