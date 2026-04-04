<a href="https://docs.world.org/world-id">
  <img src="https://raw.githubusercontent.com/worldcoin/world-id-docs/main/public/images/shared-readme/readme-header.png" alt="" />
</a>

# IDKit Swift SDK

> **Note:** This repository is the Swift Package Manager (SPM) mirror for the [worldcoin/idkit](https://github.com/worldcoin/idkit) monorepo (`swift/` directory). The Swift sources are generated via [UniFFI](https://mozilla.github.io/uniffi-rs/), giving Swift clients the exact same surface area as the Rust core. Please open issues and pull requests in the [main repository](https://github.com/worldcoin/idkit).

Swift SDK for [World ID](https://docs.world.org/world-id) verification.

## Requirements

- Xcode 16+
- iOS 15+ / macOS 12+

## Installation

Add the package to your project using SwiftPM:

```swift
.package(url: "https://github.com/worldcoin/idkit-swift", from: "4.0.2")
```

## Quick Start

```swift
import IDKit

// 1. Build RP context from your backend (never expose your signing key on the client)
let rpContext = try RpContext(
    rpId: "rp_1234567890abcdef",
    nonce: backend.nonce,
    createdAt: backend.createdAt,
    expiresAt: backend.expiresAt,
    signature: backend.sig
)

// 2. Configure the request
let config = IDKitRequestConfig(
    appId: "app_staging_1234567890abcdef",
    action: "login",
    rpContext: rpContext,
    actionDescription: "Verify Humanity",
    allowLegacyProofs: true,
    environment: .production
    bridgeUrl: nil,
    overrideConnectBaseUrl: nil,
)

// 3. Build and send the request
let request = try IDKit
    .request(config: config)
    .preset(orbLegacy(signal: "user-123"))

// 4. Generate a QR code with this URL and scan it with World App
print("Connector URL:", request.connectorURL)

// 5. Poll for the result
let completion = await request.pollUntilCompletion()
switch completion {
case .success(let result):
    // Verify this in your backend
    print("Verified", result)
case .failure(let error):
    print("Failed", error.rawValue)
}
```

## API

| Entry point              | Description                           |
| ------------------------ | ------------------------------------- |
| `IDKit.request(config:)` | Build and send a verification request |

The request object exposes:

- `connectorURL: URL` — URL for the World App QR code
- `requestID: UUID` — unique request identifier
- `pollStatusOnce()` — check status once
- `pollUntilCompletion(options:)` — poll until success or failure (configurable `pollIntervalMs` and `timeoutMs`)

## Testing

Use the [World ID Simulator](https://simulator.worldcoin.org) for development testing before going to production. Configure IDKit with `environment: .staging` when using the simulator.

## Documentation

- [IDKit Integration Guide](https://docs.world.org/world-id/idkit/integrate)
- [IDKit Swift Reference](https://docs.world.org/world-id/idkit/swift)
