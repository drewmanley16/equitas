import Foundation

actor WalletService {
    private let keychain = KeychainService()

    func createOrLoadWallet() async throws -> WalletCredentials {
        if let existingAddress = keychain.load(forKey: "walletAddress"),
           let existingMnemonic = keychain.load(forKey: "walletMnemonic") {
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
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    }

    private func deriveAddress(from mnemonic: String) -> String {
        // TODO: replace with web3swift HD wallet derivation at m/44'/60'/0'/0/0
        "0x0000000000000000000000000000000000000000"
    }
}
