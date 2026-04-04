import Foundation

@MainActor final class WalletService {
    private let keychain = KeychainService()
    private let placeholderMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let localDemoAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    private let zeroAddress = "0x0000000000000000000000000000000000000000"

    func createOrLoadWallet() async throws -> WalletCredentials {
        if let existingAddress = keychain.load(forKey: "walletAddress"),
           let existingMnemonic = keychain.load(forKey: "walletMnemonic") {
            if existingAddress.caseInsensitiveCompare(zeroAddress) == .orderedSame,
               existingMnemonic == placeholderMnemonic {
                try keychain.save(localDemoAddress, forKey: "walletAddress")
                return WalletCredentials(address: localDemoAddress, mnemonic: existingMnemonic)
            }
            return WalletCredentials(address: existingAddress, mnemonic: existingMnemonic)
        }
        // TODO: use web3swift BIP39.generateMnemonics() once SPM package is added
        let mnemonic = generatePlaceholderMnemonic()
        let address = deriveAddress(from: mnemonic)
        try keychain.save(mnemonic, forKey: "walletMnemonic")
        try keychain.save(address, forKey: "walletAddress")
        return WalletCredentials(address: address, mnemonic: mnemonic)
    }

    private func generatePlaceholderMnemonic() -> String {
        // TODO: replace with web3swift BIP39.generateMnemonics(bitsOfEntropy: 128)
        placeholderMnemonic
    }

    private func deriveAddress(from mnemonic: String) -> String {
        // TODO: replace with web3swift HD wallet derivation at m/44'/60'/0'/0/0
        if mnemonic == placeholderMnemonic {
            return localDemoAddress
        }
        return zeroAddress
    }
}
