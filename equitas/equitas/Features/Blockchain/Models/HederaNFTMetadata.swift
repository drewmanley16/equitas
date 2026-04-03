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

struct HederaNFTMintResult {
    let tokenId: String
    let serialNumber: Int
    let transactionId: String
}
