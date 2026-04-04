import Foundation
import IDKit

// MARK: - Proof (passed between steps in memory only)
struct WorldIDProof {
    let nullifierHash: String
    let merkleRoot: String
    let proof: String
    let verificationLevel: String
}

// MARK: - Backend context response
struct WorldIDContextRequest: Codable {
    let signal: String
}

struct WorldIDContextResponse: Codable {
    let nonce: String
    let rpID: String
    let createdAt: UInt64
    let expiresAt: UInt64
    let signature: String
    let appID: String
    let action: String
    let signal: String
    let environment: String

    enum CodingKeys: String, CodingKey {
        case nonce
        case rpID = "rp_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case signature
        case appID   = "app_id"
        case action
        case signal
        case environment
    }
}

// MARK: - Poll response
struct WorldIDStatusRequest: Codable {
    let nonce: String
}

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
struct WorldIDVerifyRequest: Encodable {
    let protocolVersion: String
    let nonce: String
    let action: String?
    let actionDescription: String?
    let sessionID: String?
    let responses: [WorldIDVerifyResponseItem]
    let environment: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case nonce, action, responses, environment
        case actionDescription = "action_description"
        case sessionID = "session_id"
    }

    init(result: IDKitResult) {
        self.protocolVersion = result.protocolVersion
        self.nonce = result.nonce
        self.action = result.action
        self.actionDescription = result.actionDescription
        self.sessionID = result.sessionId
        self.responses = result.responses.map(WorldIDVerifyResponseItem.init)
        self.environment = result.environment
    }
}

struct WorldIDVerifyResponse: Codable {
    let success: Bool
    let verified: Bool
}

struct WorldIDVerifyResponseItem: Encodable {
    let identifier: String
    let signalHash: String?
    let issuerSchemaID: UInt64?
    let proof: WorldIDVerifyProof
    let nullifier: String?
    let merkleRoot: String?
    let sessionNullifier: [String]?
    let expiresAtMin: UInt64?

    enum CodingKeys: String, CodingKey {
        case identifier, proof
        case signalHash = "signal_hash"
        case issuerSchemaID = "issuer_schema_id"
        case nullifier
        case merkleRoot = "merkle_root"
        case sessionNullifier = "session_nullifier"
        case expiresAtMin = "expires_at_min"
    }

    init(_ response: ResponseItem) {
        switch response {
        case .v4(let identifier, let signalHash, let issuerSchemaID, let proof, let nullifier, let expiresAtMin):
            self.identifier = identifier
            self.signalHash = signalHash
            self.issuerSchemaID = issuerSchemaID
            self.proof = .multiple(proof)
            self.nullifier = nullifier
            self.merkleRoot = nil
            self.sessionNullifier = nil
            self.expiresAtMin = expiresAtMin
        case .session(let identifier, let signalHash, let issuerSchemaID, let proof, let sessionNullifier, let expiresAtMin):
            self.identifier = identifier
            self.signalHash = signalHash
            self.issuerSchemaID = issuerSchemaID
            self.proof = .multiple(proof)
            self.nullifier = nil
            self.merkleRoot = nil
            self.sessionNullifier = sessionNullifier
            self.expiresAtMin = expiresAtMin
        case .v3(let identifier, let signalHash, let proof, let merkleRoot, let nullifier):
            self.identifier = identifier
            self.signalHash = signalHash
            self.issuerSchemaID = nil
            self.proof = .single(proof)
            self.nullifier = nullifier
            self.merkleRoot = merkleRoot
            self.sessionNullifier = nil
            self.expiresAtMin = nil
        }
    }
}

enum WorldIDVerifyProof: Encodable {
    case single(String)
    case multiple([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let proof):
            try container.encode(proof)
        case .multiple(let proof):
            try container.encode(proof)
        }
    }
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
