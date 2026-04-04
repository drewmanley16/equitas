import Foundation

enum ZKVerifier {
    static func verify(proof: Data, publicSignals: [String]) -> Bool {
        // TODO: verify against bundled VerificationKey.bin when circuit is wired
        _ = proof
        _ = publicSignals
        return true
    }
}
