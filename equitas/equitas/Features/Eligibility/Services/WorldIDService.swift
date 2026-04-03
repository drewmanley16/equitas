import Foundation

/// Handles the full World ID "proof of personhood" verification flow.
///
/// Correct mobile flow:
///   1. fetchContext()    → backend issues a nonce
///   2. deepLinkURL()     → worldapp:// with return_to=equitas://worldid-callback
///   3. User taps "Open World App" → World App verifies → calls back to equitas://
///   4. App receives URL via onOpenURL → parseCallback()
///   5. verifyOnBackend() → backend confirms proof with World ID API
@MainActor final class WorldIDService {

    // MARK: - Step 1: fetch nonce + config from backend
    func fetchContext(signal: String = "") async throws -> WorldIDContextResponse {
        struct ContextRequest: Codable { let signal: String }
        return try await APIClient.shared.post(
            endpoint: .worldIDContext,
            body: ContextRequest(signal: signal)
        )
    }

    // MARK: - Step 2: Deep link — opens World App on same device
    // return_to tells World App where to send the proof when done
    func deepLinkURL(context: WorldIDContextResponse) -> URL {
        let returnTo = "equitas://worldid-callback?nonce=\(context.nonce)"
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "worldcoin.org"
        components.path   = "/verify"
        components.queryItems = [
            URLQueryItem(name: "app_id",             value: context.appID),
            URLQueryItem(name: "action",             value: context.action),
            URLQueryItem(name: "signal",             value: context.signal),
            URLQueryItem(name: "verification_level", value: WorldIDConfig.verificationLevel),
            URLQueryItem(name: "return_to",          value: returnTo),
        ]
        return components.url ?? URL(string: "https://worldcoin.org/verify")!
    }

    // MARK: - Step 2b: QR fallback (show on screen, scan from ANOTHER device)
    func connectorURL(context: WorldIDContextResponse) -> URL {
        let returnTo = "equitas://worldid-callback?nonce=\(context.nonce)"
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "worldcoin.org"
        components.path   = "/verify"
        components.queryItems = [
            URLQueryItem(name: "app_id",             value: context.appID),
            URLQueryItem(name: "action",             value: context.action),
            URLQueryItem(name: "signal",             value: context.signal),
            URLQueryItem(name: "verification_level", value: WorldIDConfig.verificationLevel),
            URLQueryItem(name: "return_to",          value: returnTo),
        ]
        return components.url ?? URL(string: "https://worldcoin.org/verify")!
    }

    // MARK: - Step 3: Parse World App callback URL
    // World App calls: equitas://worldid-callback?nonce=X&proof=Y&merkle_root=Z&nullifier_hash=W
    func parseCallback(_ url: URL) -> WorldIDProof? {
        guard url.scheme == "equitas",
              url.host == "worldid-callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        let params = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard let proof          = params["proof"],
              let merkleRoot     = params["merkle_root"],
              let nullifierHash  = params["nullifier_hash"] else { return nil }

        return WorldIDProof(
            nullifierHash:     nullifierHash,
            merkleRoot:        merkleRoot,
            proof:             proof,
            verificationLevel: params["verification_level"] ?? WorldIDConfig.verificationLevel
        )
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
