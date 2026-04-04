import Foundation

/// ARC programmable USDC: eligibility unlocks restricted USDC held in `SNAPSpender` (no separate SNAP ERC-20).
actor SNAPBenefitsService {
    func fundBenefitsAfterEligibility(
        walletAddress: String,
        nftSerial: Int,
        proofHash: String
    ) async throws {
        let _: ARCIssueTokensResponse = try await APIClient.shared.post(
            endpoint: .issueTokens,
            body: ARCIssueTokensRequest(
                walletAddress: walletAddress,
                serialNumber: nftSerial,
                proofHash: proofHash
            )
        )
    }
}
