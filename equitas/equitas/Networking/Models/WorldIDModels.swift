import Foundation

// MARK: - Proof (passed between steps in memory only)
struct WorldIDProof {
    let nullifierHash: String
    let merkleRoot: String
    let proof: String
    let verificationLevel: String
}

// MARK: - Backend context response
struct WorldIDContextResponse: Codable {
    let nonce: String
    let appID: String
    let action: String
    let signal: String

    enum CodingKeys: String, CodingKey {
        case nonce
        case appID   = "app_id"
        case action
        case signal
    }
}

// MARK: - Poll response
struct WorldIDStatusResponse: Codable {
    /// "pending" | "success" | "failed"
    let status: String
    let proof: String?
    let merkleRoot: String?
    let nullifierHash: String?
    let verificationLevel: String?

    enum CodingKeys: String, CodingKey {
        case status, proof
        case merkleRoot      = "merkle_root"
        case nullifierHash   = "nullifier_hash"
        case verificationLevel = "verification_level"
    }

    var isSuccess: Bool { status == "success" }
    var isPending: Bool { status == "pending" }
}

// MARK: - Verify request / response
struct WorldIDVerifyRequest: Codable {
    let proof: String
    let merkleRoot: String
    let nullifierHash: String
    let verificationLevel: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case proof, nonce
        case merkleRoot      = "merkle_root"
        case nullifierHash   = "nullifier_hash"
        case verificationLevel = "verification_level"
    }
}

struct WorldIDVerifyResponse: Codable {
    let success: Bool
    let verified: Bool
}

// MARK: - OIDC exchange (iOS sends auth code + PKCE verifier; backend does token swap)
struct WorldIDOIDCExchangeRequest: Codable {
    let code: String
    let state: String
    let codeVerifier: String

    enum CodingKeys: String, CodingKey {
        case code, state
        case codeVerifier = "code_verifier"
    }
}

struct WorldIDOIDCExchangeResponse: Codable {
    let success: Bool
    let verified: Bool
    let nullifierHash: String?

    enum CodingKeys: String, CodingKey {
        case success, verified
        case nullifierHash = "nullifier_hash"
    }
}

// MARK: - Errors
enum WorldIDError: Error, LocalizedError {
    case contextFetchFailed
    case pollingTimeout
    case verificationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .contextFetchFailed:  return "Could not start World ID verification."
        case .pollingTimeout:      return "Verification timed out. Please try again."
        case .verificationFailed:  return "World ID proof could not be verified."
        case .cancelled:           return "Verification was cancelled."
        }
    }
}
