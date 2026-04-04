# Equitas

SNAP eligibility verification with zero-knowledge proofs, Hedera NFT portability, and **ARC programmable USDC** via the `SNAPSpender` contract (restricted merchant spend — no separate SNAP-pegged token).

## iOS app

Open `equitas/equitas.xcodeproj` in Xcode. Build the `equitas` scheme.

Optional: set `EquitasAPIBaseURL` in the app Info.plist to your Mac’s LAN URL when testing on a physical device (defaults to `http://127.0.0.1:3000` for Simulator).

## Safe local demo (Anvil — no real funds)

See [LOCAL_DEMO.md](LOCAL_DEMO.md) for a full **localhost-only** ARC flow (Anvil, MockUSDC, disposable keys).

## Backend (benefits API)

Stateless Express service that drives `SNAPSpender` with an operator wallet.

```bash
cd backend
npm install
cp .env.example .env
# fill RPC_URL, OPERATOR_PRIVATE_KEY, SNAP_SPENDER_ADDRESS, USDC_ADDRESS
npm start
```

Core routes:

- `GET /api/health`
- `POST /api/benefits/approve-user`
- `POST /api/benefits/deposit`
- `POST /api/benefits/setup-merchant`
- `GET /api/benefits/status/:userAddress`

Optional demo route (signs `payMerchant` with a beneficiary key — not for production):

- `POST /api/benefits/pay-merchant`

## Hedera minting process

The Hedera NFT is the eligibility attestation artifact. It stores the wallet address, income-proof hash, and World ID nullifier in NFT metadata on Hedera testnet.

Required backend env:

- `HEDERA_ACCOUNT_ID`
- `HEDERA_PRIVATE_KEY` from Hedera Portal for that exact account
- `HEDERA_NETWORK=testnet`

If Hedera Portal shows a `HEX Encoded Private Key`, you can paste that value directly into `HEDERA_PRIVATE_KEY`. The backend now accepts hex ECDSA/ED25519 keys as well as DER-formatted keys.

Create the NFT collection first to get `HEDERA_TOKEN_ID`:

```bash
cd backend
npm run create:hedera-nft
```

Optional flags:

```bash
npm run create:hedera-nft -- \
  --name "Equitas SNAP Eligibility" \
  --symbol EQUITAS \
  --memo "Equitas eligibility attestation NFT" \
  --max-supply 100000
```

The script prints a token ID like `0.0.1234567`. Put that into `backend/.env`:

```env
HEDERA_TOKEN_ID=0.0.1234567
```

Run a direct mint smoke test:

```bash
cd backend
npm run mint:hedera -- \
  --wallet 0xYourWalletAddress \
  --proof zk-proof-hash-from-backend \
  --nullifier worldid-nullifier
```

Or call the API route the app uses:

```bash
curl -X POST http://127.0.0.1:3000/api/blockchain/mint-nft \
  -H 'Content-Type: application/json' \
  -d '{
    "walletAddress":"0xYourWalletAddress",
    "proofHash":"zk-proof-hash-from-backend",
    "worldIDNullifier":"worldid-nullifier"
  }'
```

Expected flow:

- World ID verification completes.
- Income proof hash is generated.
- `POST /api/blockchain/mint-nft` mints the Hedera testnet NFT.
- `POST /api/blockchain/issue-tokens` releases ARC benefits only after the NFT mint succeeds.

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
