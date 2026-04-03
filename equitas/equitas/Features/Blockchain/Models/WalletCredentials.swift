import Foundation

struct WalletCredentials {
    let address: String
    let mnemonic: String  // stored encrypted in Keychain, never in memory longer than needed
}
