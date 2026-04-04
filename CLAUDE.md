# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Equitas** — SNAP Benefits Verification iOS app. Users prove SNAP eligibility via ZK proofs (no raw financial data stored or transmitted), receive SNAPtokens on the ARC/Circles network (Gnosis Chain, chain ID 100), and get a Hedera HTS NFT as a portable, reusable proof of eligibility.

**Hackathon targets:**
- Hedera: HTS tokenization bounty — NFT minting with KYC/freeze controls, testnet deployment
- ARC/Circle: Advanced stablecoin logic bounty — conditional USDC flows, frontend + backend MVP

## Build & Run

### iOS app

The Xcode project is at `equitas/equitas.xcodeproj`. There is no `Package.swift` — dependencies are managed via Xcode's SPM UI.

```bash
# Build from CLI (simulator)
xcodebuild -project equitas/equitas.xcodeproj \
           -scheme equitas \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build

# Run tests
xcodebuild -project equitas/equitas.xcodeproj \
           -scheme equitas \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           test
```

**SPM dependencies** (must be added via Xcode SPM UI if missing):
- `https://github.com/worldcoin/idkit-swift` — from `4.0.2` *(currently integrated)*
- `https://github.com/web3swift-team/web3swift` — `.upToNextMajor(from: "3.0.0")` *(not yet added — `WalletService` has placeholder BIP39)*
- `https://github.com/krzyzanowskim/CryptoSwift` — from `1.9.0`

### Backend (TypeScript/Express)

```bash
cd backend

npm run dev      # ts-node with nodemon — runs on port 3000
npm run build    # compile to dist/
npm start        # run compiled dist/index.js
```

The iOS app in `#if DEBUG` targets `http://localhost:3000`; production targets `https://api.equitas.app`. Set env vars in a `.env` file in `backend/` (Hedera operator key, World ID app secret, etc.).

## Architecture

### App entry & routing

`equitasApp.swift` → `AppRouter` (already wired). `AppRouter` switches on `AppState.authState` (unauthenticated / lockedAuthenticated / unlocked) and `AppState.isEligibilityComplete` to gate access. `AppState` is `@Observable @MainActor` injected via `.environment(appState)`.

Auth is determined at init: if `KeychainService` has `"appleUserID"`, start as `.lockedAuthenticated` (require Face ID); otherwise `.unauthenticated` (show Apple Sign-In).

### Eligibility flow (the core product)

`EligibilityRootView` drives a 3-step state machine in `EligibilityViewModel.currentStep`:

1. **World ID** (`WorldIDStepView`) — Two parallel paths both resolve to `completeWorldIDVerification`:
   - *IDKit polling*: `request.pollUntilCompletion()` waits for World App scan of QR code
   - *Legacy callback*: `equitas://worldid-callback` deep link arrives via `onOpenURL` → `service.parseCallback(url)` → backend verify

2. **Income ZK proof** (`IncomeVerificationStepView`) — VisionKit OCR scans paystub → `IncomeHashingService` SHA-256 hashes fields on-device → raw values zeroed → hashes sent to backend `ZKProofService` → proof verified locally against bundled `VerificationKey.bin`.

3. **Blockchain orchestration** (`ProcessingStepView`) — sequential: create/load BIP39 wallet → Circles v2 registration on Gnosis Chain → Hedera NFT mint (via backend) → SNAPtoken issuance (via backend).

**Privacy invariant:** Raw income values (`IncomeFields`) must never be persisted or sent over the network. Only `HashedIncomeFields` leaves the device.

### Service layer conventions

- All `Service` types are `actor` (thread-safe mutable state)
- All `ViewModel` types are `@Observable @MainActor`
- Views are pure SwiftUI structs; no business logic
- `APIClient.shared` is the single URLSession entry point — all backend calls go through `APIEndpoints.swift`
- `KeychainService` is the only persistence for sensitive data (mnemonic, address, session token)

### Blockchain layers

| Chain | Service | Purpose |
|---|---|---|
| Gnosis Chain (100) | `GnosisChainService`, `CirclesWalletService`, `SNAPtokenService` | Circles v2 wallet registration, SNAPtoken (ERC-20) balance + transfer |
| Hedera Testnet | `HederaService` | NFT mint via backend `@hashgraph/sdk` (HTS native — not EVM) |

Hedera operations go through the backend because HTS native token minting cannot be done via EVM JSON-RPC. The iOS app never holds the Hedera operator key.

`WalletService` generates a single BIP39/BIP44 HD wallet (`m/44'/60'/0'/0/0`) used for both chains — currently a placeholder pending `web3swift` SPM addition.

### Backend routes

| Route | File | Status |
|---|---|---|
| `POST /api/auth/verify-apple` | `routes/auth.ts` | — |
| `POST /api/worldid/context` | `routes/worldid.ts` | Working |
| `POST /api/worldid/status` | `routes/worldid.ts` | Working (polls in-memory session) |
| `POST /api/worldid/verify` | `routes/worldid.ts` | Working; staging bypasses API check |
| `POST /api/worldid/oidc-exchange` | `routes/worldid.ts` | Working (PKCE code → nullifier_hash) |
| `POST /api/zk/prove` | `routes/zk.ts` | — |
| `POST /api/blockchain/mint-nft` | `routes/blockchain.ts` | Working (Hedera testnet) |
| `POST /api/blockchain/issue-tokens` | `routes/blockchain.ts` | Stub — returns demo `txHash` |

## Key implementation gaps (TODOs)

- `WalletService` BIP39/HD derivation — placeholder until `web3swift` is added via Xcode SPM UI
- `DocumentScannerService` — needs real `VNDocumentCameraViewController` presentation
- `ZKVerifier.swift` is empty — needs bundled `VerificationKey.bin` and Noir verification logic
- `backend/src/routes/blockchain.ts` `issue-tokens` — returns demo data; needs ethers.js ERC-20 mint on Gnosis Chiado
- `backend/src/routes/zk.ts` — ZK proof generation (Noir circuit) not yet wired

## Testnet config

- Hedera: testnet (`testnet.hedera.com`), mirror node at `https://testnet.mirrornode.hedera.com`
- Gnosis: Chiado testnet (chain ID 10200), RPC `https://rpc.chiadochain.net`
- World ID: staging app ID from developer.worldcoin.org (staging env bypasses actual proof verification on backend)
