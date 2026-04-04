# Equitas

SNAP eligibility verification with zero-knowledge proofs, Hedera NFT portability, and **ARC programmable USDC** via the `SNAPSpender` contract (restricted merchant spend — no separate SNAP-pegged token).

## iOS app

Open `equitas/equitas.xcodeproj` in Xcode. Build the `equitas` scheme.

Optional: set `EquitasAPIBaseURL` in the app Info.plist to your Mac’s LAN URL when testing on a physical device (defaults to `http://127.0.0.1:3000` for Simulator).

## Safe local demo (Anvil — no real funds)

See [LOCAL_DEMO.md](LOCAL_DEMO.md) for a full **localhost-only** ARC flow (Anvil, MockUSDC, disposable keys).

## Backend (benefits API)

Stateless Express service that drives `SNAPSpender` with an operator wallet.

**Post-verification funding:** Identity and ZK proof verification are handled elsewhere (e.g. the iOS app or another service). This benefits server does **not** verify proofs. After verification succeeds, clients call `POST /api/post-verification/process` with income and household inputs; the server computes the benefit, then sets eligibility and allowance on `SNAPSpender` and pulls the matching USDC into the contract. There is **no** separate SNAP-pegged token — benefits are **restricted USDC** held in `SNAPSpender` until spent at approved merchants.

```bash
cd backend
npm install
cp .env.example .env
# fill RPC_URL, OPERATOR_PRIVATE_KEY, SNAP_SPENDER_ADDRESS, USDC_ADDRESS
npm start
```

Core routes:

- `GET /api/health`
- `POST /api/post-verification/process` — hand off from successful verification to on-chain funding (see [backend/API_EXAMPLES.md](backend/API_EXAMPLES.md))
- `POST /api/benefits/approve-user`
- `POST /api/benefits/deposit`
- `POST /api/benefits/setup-merchant`
- `GET /api/benefits/status/:userAddress`

Optional demo route (signs `payMerchant` with a beneficiary key — not for production):

- `POST /api/benefits/pay-merchant`

## Smart contracts (Foundry)

Canonical sources live under `blockchain/src/`. Symlinks `blockchain/SNAPSpender.sol` and `blockchain/MockUSDC.sol` point at those files.

```bash
cd blockchain
./install-deps.sh   # requires [Foundry](https://book.getfoundry.sh/getting-started/installation)
forge build
forge test
```

Deploy (example):

```bash
cd blockchain
export PRIVATE_KEY=0x...
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --broadcast
```

Use Chiado testnet RPC, e.g. `https://rpc.chiadochain.net`, and a funded operator account for gas.

After deploy, mint Mock USDC to the operator, `approve` the `SNAPSpender` address, call `setup-merchant` via API, then run the eligibility flow so `approve-user` + `deposit` can fund benefits.

## ARC bounty model

- **USDC only** — benefits live as USDC inside `SNAPSpender`.
- **Rules on-chain** — approved users, approved merchants, per-user allowance vs spent, optional expiry, pausable.
- **iOS** — `SNAPBenefitsService` replaces token issuance with “SNAP benefits funding”; `WalletViewModel` shows remaining balance from the API; `PaymentService` calls the optional pay endpoint for demos without on-device signing.
