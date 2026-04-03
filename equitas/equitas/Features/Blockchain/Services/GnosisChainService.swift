import Foundation

// Gnosis Chain (chain ID 100)
// RPC: https://rpc.gnosischain.com
actor GnosisChainService {
    private let rpcURL = URL(string: "https://rpc.gnosischain.com")!
    private let chainID: Int = 100

    func getBalance(address: String) async throws -> String {
        // TODO: web3swift eth_getBalance call
        return "0"
    }

    func sendTransaction(signedTx: Data) async throws -> String {
        // TODO: web3swift eth_sendRawTransaction
        return "0x"
    }
}
