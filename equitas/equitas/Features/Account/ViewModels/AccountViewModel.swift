import Foundation

@Observable
@MainActor
final class AccountViewModel {
    var walletAddress: String = "No wallet connected"
    var linkedNFT: LinkedHederaNFT?

    private let keychain = KeychainService()

    func refresh() {
        walletAddress = keychain.load(forKey: "walletAddress") ?? "No wallet connected"

        guard let tokenId = keychain.load(forKey: "hederaTokenId"),
              let serialValue = keychain.load(forKey: "hederaSerialNumber"),
              let serialNumber = Int(serialValue) else {
            linkedNFT = nil
            return
        }

        linkedNFT = LinkedHederaNFT(
            tokenId: tokenId,
            serialNumber: serialNumber,
            transactionId: keychain.load(forKey: "hederaTransactionId"),
            hederaAccountId: keychain.load(forKey: "hederaAccountId"),
            issuedAt: keychain.load(forKey: "hederaIssuedAt")
        )
    }

    func shortenedAddress(_ value: String) -> String {
        guard value.count > 14 else { return value }
        return "\(value.prefix(8))...\(value.suffix(6))"
    }
}

struct LinkedHederaNFT {
    let tokenId: String
    let serialNumber: Int
    let transactionId: String?
    let hederaAccountId: String?
    let issuedAt: String?

    var tokenExplorerURL: URL? {
        URL(string: "https://hashscan.io/testnet/token/\(tokenId)")
    }

    var transactionExplorerURL: URL? {
        guard let transactionId else { return nil }
        return URL(string: "https://hashscan.io/testnet/transaction/\(transactionId)")
    }

    var issuedLabel: String {
        guard let issuedAt,
              let date = ISO8601DateFormatter().date(from: issuedAt) else {
            return "Linked"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
