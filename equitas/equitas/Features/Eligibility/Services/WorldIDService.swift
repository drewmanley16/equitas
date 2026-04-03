import Foundation

/// Handles World ID proof-of-personhood verification.
///
/// Flow:
///   1. verificationURL(nonce:)  → URL with return_to=equitas://worldid-callback
///   2. Show URL as QR  +  "Open World App" button (openURL)
///   3. World App verifies → opens equitas://worldid-callback?proof=...
///   4. parseCallback(_:)       → WorldIDProof
///   5. verifyOnBackend(proof:nonce:) → confirmed on server
@MainActor final class WorldIDService {

    // MARK: - Verification URL (QR + deep link)

    /// Builds a worldcoin.org/verify URL that World App understands.
    /// Works as both a deep link (tap button) and a QR code (scan with World App).
    func verificationURL(nonce: String) -> URL {
        let returnTo = "equitas://worldid-callback?nonce=\(nonce)"

        // Percent-encode the return_to value (unreserved chars only)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = returnTo.addingPercentEncoding(withAllowedCharacters: allowed) ?? returnTo

        let str = "https://worldcoin.org/verify"
            + "?app_id=\(WorldIDConfig.appID)"
            + "&action=\(WorldIDConfig.action)"
            + "&signal="
            + "&verification_level=\(WorldIDConfig.verificationLevel)"
            + "&return_to=\(encoded)"

        return URL(string: str)!
    }

    // MARK: - Callback parsing

    /// Parses equitas://worldid-callback?proof=X&merkle_root=Y&nullifier_hash=Z
    func parseCallback(_ url: URL) -> WorldIDProof? {
        guard url.scheme == "equitas",
              url.host == "worldid-callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        let params = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard let proof         = params["proof"],
              let merkleRoot    = params["merkle_root"],
              let nullifierHash = params["nullifier_hash"] else { return nil }

        return WorldIDProof(
            nullifierHash:     nullifierHash,
            merkleRoot:        merkleRoot,
            proof:             proof,
            verificationLevel: params["verification_level"] ?? WorldIDConfig.verificationLevel
        )
    }

    // MARK: - Backend verification

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
