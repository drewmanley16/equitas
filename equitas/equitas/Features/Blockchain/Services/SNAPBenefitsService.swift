import Foundation

/// ARC programmable USDC: eligibility unlocks restricted USDC held in `SNAPSpender` (no separate SNAP ERC-20).
actor SNAPBenefitsService {
    func fundBenefitsAfterEligibility(
        walletAddress: String,
        hederaTokenId: String,
        nftSerial: Int,
    ) async throws -> ARCIssueTokensResponse {
        try await APIClient.shared.post(
            endpoint: .issueTokens,
            body: ARCIssueTokensRequest(
                walletAddress: walletAddress,
                hederaTokenId: hederaTokenId,
                serialNumber: nftSerial
            )
        )
    }
}
