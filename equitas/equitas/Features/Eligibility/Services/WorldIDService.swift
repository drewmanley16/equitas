import Foundation

/// Handles the full World ID "proof of personhood" verification flow.
///
/// Flow:
///   1. fetchContext()       → backend issues a nonce + signed RP context
///   2. connectorURL(...)    → QR code URL displayed to user
///   3. deepLinkURL(...)     → worldapp:// URL for same-device tap
///   4. pollUntilComplete()  → loops until World App submits the proof
///   5. verifyOnBackend()    → backend confirms the proof is valid on-chain
///
/// NOTE: idkit-swift SPM package (https://github.com/worldcoin/idkit-swift)
/// should be added via Xcode once the App ID is registered. Until then,
/// the connector/deep-link URLs are constructed manually from the spec.
@MainActor final class WorldIDService {

    // MARK: - Step 1: fetch RP context from backend
    func fetchContext(signal: String = "") async throws -> WorldIDContextResponse {
        struct ContextRequest: Codable { let signal: String }
        return try await APIClient.shared.post(
            endpoint: .worldIDContext,
            body: ContextRequest(signal: signal)
        )
    }

    // MARK: - Step 2a: QR code URL (scan from World App on another device)
    func connectorURL(context: WorldIDContextResponse) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "worldcoin.org"
        components.path   = "/verify"
        components.queryItems = [
            URLQueryItem(name: "app_id",              value: context.appID),
            URLQueryItem(name: "action",              value: context.action),
            URLQueryItem(name: "signal",              value: context.signal),
            URLQueryItem(name: "nonce",               value: context.nonce),
            URLQueryItem(name: "verification_level",  value: WorldIDConfig.verificationLevel),
        ]
        return components.url ?? URL(string: "https://worldcoin.org/verify")!
    }

    // MARK: - Step 2b: Deep link (opens World App on the SAME device)
    func deepLinkURL(context: WorldIDContextResponse) -> URL {
        var components = URLComponents()
        components.scheme = "worldapp"
        components.host   = "verify"
        components.queryItems = [
            URLQueryItem(name: "app_id",              value: context.appID),
            URLQueryItem(name: "action",              value: context.action),
            URLQueryItem(name: "signal",              value: context.signal),
            URLQueryItem(name: "nonce",               value: context.nonce),
            URLQueryItem(name: "verification_level",  value: WorldIDConfig.verificationLevel),
        ]
        return components.url ?? URL(string: "worldapp://verify")!
    }

    // MARK: - Step 3: Poll backend until World App submits the proof
    func pollUntilComplete(nonce: String) async throws -> WorldIDProof {
        struct PollRequest: Codable { let nonce: String }

        for attempt in 0..<WorldIDConfig.maxPollAttempts {
            try Task.checkCancellation()

            if attempt > 0 {
                try await Task.sleep(nanoseconds: WorldIDConfig.pollInterval)
            }

            let status: WorldIDStatusResponse = try await APIClient.shared.post(
                endpoint: .worldIDStatus,
                body: PollRequest(nonce: nonce)
            )

            if status.isSuccess,
               let proof           = status.proof,
               let merkleRoot      = status.merkleRoot,
               let nullifierHash   = status.nullifierHash,
               let verificationLevel = status.verificationLevel {
                return WorldIDProof(
                    nullifierHash:     nullifierHash,
                    merkleRoot:        merkleRoot,
                    proof:             proof,
                    verificationLevel: verificationLevel
                )
            }

            if !status.isPending { throw WorldIDError.verificationFailed }
        }

        throw WorldIDError.pollingTimeout
    }

    // MARK: - Step 4: Final server-side verification
    func verifyOnBackend(proof: WorldIDProof, nonce: String) async throws -> Bool {
        let request = WorldIDVerifyRequest(
            proof:             proof.proof,
            merkleRoot:        proof.merkleRoot,
            nullifierHash:     proof.nullifierHash,
            verificationLevel: proof.verificationLevel,
            nonce:             nonce
        )
        let response: WorldIDVerifyResponse = try await APIClient.shared.post(
            endpoint: .worldIDVerify,
            body: request
        )
        guard response.verified else { throw WorldIDError.verificationFailed }
        return true
    }
}
