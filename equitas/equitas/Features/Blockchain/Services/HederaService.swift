import Foundation

actor HederaService {
    func mintEligibilityNFT(wallet: WalletCredentials) async throws -> HederaNFTMintResult {
        let request = HederaNFTMintRequest(
            walletAddress: wallet.address,
            proofHash: "placeholder",
            worldIDNullifier: "placeholder"
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
