import Foundation
import IDKit

struct WorldIDVerificationSession {
    let nonce: String
    let connectorURL: URL
    let request: IDKitRequest
}

/// Handles World ID proof-of-personhood verification using IDKit.
///
/// Flow:
///   1. startVerification()     → fetch backend RP context + build IDKit request
///   2. Show connector URL as QR + "Open World App" button
///   3. request.pollUntilCompletion() waits for World App confirmation
///   4. verifyOnBackend(result:) forwards the proof payload to World verify API
@MainActor final class WorldIDService {

    func startVerification(signal: String = "") async throws -> WorldIDVerificationSession {
        let context: WorldIDContextResponse = try await APIClient.shared.post(
            endpoint: .worldIDContext,
            body: WorldIDContextRequest(signal: signal)
        )

        let rpContext = try RpContext(
            rpId: context.rpID,
            nonce: context.nonce,
            createdAt: context.createdAt,
            expiresAt: context.expiresAt,
            signature: context.signature
        )

        let config = IDKitRequestConfig(
            appId: context.appID,
            action: context.action,
            rpContext: rpContext,
            actionDescription: "Verify Humanity",
            bridgeUrl: nil,
            allowLegacyProofs: true,
            overrideConnectBaseUrl: nil,
            returnTo: "equitas://worldid-callback?nonce=\(context.nonce)",
            environment: environment(from: context.environment),
            connectUrlMode: .default
        )

        let request = try IDKit.request(config: config)
            .preset(deviceLegacy(signal: context.signal.isEmpty ? nil : context.signal))

        return WorldIDVerificationSession(
            nonce: context.nonce,
            connectorURL: request.connectorURL,
            request: request
        )
    }

    func parseCallback(_ url: URL) -> WorldIDProof? {
        guard url.scheme == "equitas",
              url.host == "worldid-callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        let params = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard let proof = params["proof"],
              let merkleRoot = params["merkle_root"],
              let nullifierHash = params["nullifier_hash"] else { return nil }

        return WorldIDProof(
            nullifierHash: nullifierHash,
            merkleRoot: merkleRoot,
            proof: proof,
            verificationLevel: params["verification_level"] ?? WorldIDConfig.verificationLevel
        )
    }

    func verifyOnBackend(result: IDKitResult) async throws -> Bool {
        let response: WorldIDVerifyResponse = try await APIClient.shared.post(
            endpoint: .worldIDVerify,
            body: WorldIDVerifyRequest(result: result)
        )
        guard response.verified else { throw WorldIDError.verificationFailed }
        return true
    }

    func verifyOnBackend(proof: WorldIDProof, nonce: String) async throws -> Bool {
        let request = LegacyWorldIDVerifyRequest(
            proof: proof.proof,
            merkleRoot: proof.merkleRoot,
            nullifierHash: proof.nullifierHash,
            verificationLevel: proof.verificationLevel,
            nonce: nonce
        )
        let response: WorldIDVerifyResponse = try await APIClient.shared.post(
            endpoint: .worldIDVerify,
            body: request
        )
        guard response.verified else { throw WorldIDError.verificationFailed }
        return true
    }

    private func environment(from value: String) -> Environment {
        value.lowercased() == "staging" ? .staging : .production
    }
}

private struct LegacyWorldIDVerifyRequest: Codable {
    let proof: String
    let merkleRoot: String
    let nullifierHash: String
    let verificationLevel: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case proof, nonce
        case merkleRoot = "merkle_root"
        case nullifierHash = "nullifier_hash"
        case verificationLevel = "verification_level"
    }
}
