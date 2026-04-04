import Foundation

struct HederaNFTMetadata: Codable {
    let name: String
    let description: String
    let walletAddress: String
    let zkProofHash: String
    let worldIDNullifier: String
    let issuedAt: String

    static func eligibility(
        walletAddress: String,
        zkProofHash: String,
        worldIDNullifier: String
    ) -> HederaNFTMetadata {
        HederaNFTMetadata(
            name: "SNAP Eligibility — Equitas",
            description: "Zero-knowledge proof of SNAP eligibility. No personal data stored.",
            walletAddress: walletAddress,
            zkProofHash: zkProofHash,
            worldIDNullifier: worldIDNullifier,
            issuedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

struct HederaNFTMintRequest: Codable {
    let walletAddress: String
    let proofHash: String
    let worldIDNullifier: String
}

struct HederaNFTMintResponse: Codable {
    let hederaTokenId: String
    let serialNumber: Int
    let txId: String
    let hederaAccountId: String?
    let createdRecipientAccount: Bool?
    let allowanceAtomic: String?
    let benefitTier: String?
}

struct HederaNFTMintResult {
    let tokenId: String
    let serialNumber: Int
    let transactionId: String
    let hederaAccountId: String?
    let createdRecipientAccount: Bool
    let allowanceAtomic: String?
    let benefitTier: String?
}

struct ARCIssueTokensRequest: Codable {
    let walletAddress: String
    let hederaTokenId: String
    let serialNumber: Int
}

struct ARCIssueTokensResponse: Codable {
    let ok: Bool
    let serialNumber: Int
    let proofHash: String
    let hederaTokenId: String?
    let allowanceAtomic: String
    let benefitTier: String
    let explorerBaseURL: String?
    let eligibilityTxHash: String
    let allowanceTxHash: String
    let depositTxHash: String
    let eligibilityExplorerURL: String?
    let allowanceExplorerURL: String?
    let depositExplorerURL: String?
}
