import Foundation

struct HederaNFTMintRequest: Codable {
    let walletAddress: String
    let proofHash: String
    let worldIDNullifier: String
}

struct HederaNFTMintResponse: Codable {
    let hederaTokenId: String
    let serialNumber: Int
    let txId: String
}
