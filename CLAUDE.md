# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Equitas** — SNAP Benefits Verification iOS app. Users prove SNAP eligibility via ZK proofs (no raw financial data stored or transmitted), receive SNAPtokens on the ARC/Circles network (Gnosis Chain, chain ID 100), and get a Hedera HTS NFT as a portable, reusable proof of eligibility.

**Hackathon targets:**
- Hedera: HTS tokenization bounty — NFT minting with KYC/freeze controls, testnet deployment
- ARC/Circle: Advanced stablecoin logic bounty — conditional USDC flows, frontend + backend MVP

## Build & Run

The Xcode project is at `equitas/equitas.xcodeproj`. There is no `Package.swift` — dependencies are added via Xcode's SPM UI.

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

**SPM dependencies to add** (not yet added — must be done via Xcode):
- `https://github.com/worldcoin/idkit-swift` — from `4.0.2`
- `https://github.com/web3swift-team/web3swift` — `.upToNextMajor(from: "3.0.0")`
- `https://github.com/krzyzanowskim/CryptoSwift` — from `1.9.0`

## Architecture

### App entry & routing

`equitasApp.swift` → `ContentView` (needs updating to `AppRouter`). `AppRouter` switches on `AppState.authState` (unauthenticated / lockedAuthenticated / unlocked) and `AppState.isEligibilityComplete` to gate access. `AppState` is `@Observable @MainActor` and should be injected as `.environment(AppState())` in the app entry point.

### Eligibility flow (the core product)

`EligibilityRootView` drives a 3-step state machine in `EligibilityViewModel.currentStep`:

1. **World ID** (`WorldIDStepView`) — QR code + polling via `idkit-swift`. Requires backend RP context endpoint.
2. **Income ZK proof** (`IncomeVerificationStepView`) — VisionKit OCR scans paystub → `IncomeHashingService` SHA-256 hashes fields on-device → raw values zeroed → hashes sent to backend `ZKProofService` → proof verified locally against bundled `VerificationKey.bin`.
3. **Blockchain orchestration** (`ProcessingStepView`) — sequential: create/load BIP39 wallet → Circles v2 registration on Gnosis Chain → Hedera NFT mint (via backend) → SNAPtoken issuance (via backend).

**Privacy invariant:** Raw income values (`IncomeFields`) must never be persisted or sent over the network. Only `HashedIncomeFields` leaves the device.

### Service layer conventions

- All `Service` types are `actor` (thread-safe mutable state)
- All `ViewModel` types are `@Observable @MainActor`
- Views are pure SwiftUI structs; no business logic
- `APIClient.shared` is the single URLSession entry point for all backend calls
- `KeychainService` is the only persistence for sensitive data (mnemonic, address, session token)

### Blockchain layers

| Chain | Service | Purpose |
|---|---|---|
| Gnosis Chain (100) | `GnosisChainService`, `CirclesWalletService`, `SNAPtokenService` | Circles v2 wallet registration, SNAPtoken (ERC-20) balance + transfer |
| Hedera Testnet | `HederaService` | NFT mint via backend Node.js Hedera SDK (HTS native — not EVM) |

Hedera operations go through the backend because HTS native token minting cannot be done via EVM JSON-RPC. The iOS app never holds the Hedera operator key.

`WalletService` generates a single BIP39/BIP44 HD wallet (`m/44'/60'/0'/0/0`) used for both Gnosis Chain and Hedera EVM-compatible operations.

### Backend (not yet built)

Stateless Node.js/Express signing service. Required endpoints: Apple sign-in verification, World ID RP context + proof verification, ZK proof generation (Noir circuit), Hedera NFT mint, SNAPtoken issuance, PassKit `.pkpass` generation. No database — all state lives on-chain or in device Keychain.

## Key implementation gaps (TODOs)

- `equitasApp.swift` still renders `ContentView` — needs `AppRouter` + `AppState` environment injection
- `WalletService` has placeholder BIP39 — blocked on `web3swift` SPM addition
- `WorldIDService` has placeholder — blocked on `idkit-swift` SPM addition
- `DocumentScannerService` needs real `VNDocumentCameraViewController` presentation
- All `Networking/` model files are empty — need Codable types matching backend contracts
- All `Wallet/` and `Account/` views are empty stubs
- `ZKVerifier.swift` is empty — needs bundled `VerificationKey.bin` and verification logic

## Testnet config

- Hedera: use testnet (`testnet.hedera.com`), mirror node at `https://testnet.mirrornode.hedera.com`
- Gnosis: use Chiado testnet (chain ID 10200), RPC `https://rpc.chiadochain.net`
- World ID: staging app ID from developer.worldcoin.org
