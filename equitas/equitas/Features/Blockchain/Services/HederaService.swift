import Foundation

@MainActor final class HederaService {
    func mintEligibilityNFT(
        wallet: WalletCredentials,
        proofHash: String,
        worldIDNullifier: String
    ) async throws -> HederaNFTMintResult {
        let request = HederaNFTMintRequest(
            walletAddress: wallet.address,
            proofHash: proofHash,
            worldIDNullifier: worldIDNullifier
        )
        let response: HederaNFTMintResponse = try await APIClient.shared.post(
            endpoint: .mintNFT,
            body: request
        )
        return HederaNFTMintResult(
            tokenId: response.hederaTokenId,
            serialNumber: response.serialNumber,
            transactionId: response.txId
        )
    }
}
