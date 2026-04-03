import Foundation

actor SNAPtokenService {
    func getBalance(address: String) async throws -> Double {
        // TODO: ERC-20 balanceOf call via web3swift on Gnosis Chain
        return 0.0
    }

    func issueInitialTokens(to address: String, nftSerial: Int) async throws {
        struct IssueRequest: Codable {
            let walletAddress: String
            let serialNumber: Int
        }
        struct IssueResponse: Codable {
            let txHash: String
            let amount: String
        }
        let _: IssueResponse = try await APIClient.shared.post(
            endpoint: .issueTokens,
            body: IssueRequest(walletAddress: address, serialNumber: nftSerial)
        )
    }

    func transfer(to address: String, amount: Double) async throws -> String {
        // TODO: ERC-20 transfer via web3swift on Gnosis Chain
        return "0x"
    }
}
