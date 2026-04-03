import Foundation

final class ZKVerifier {
    static let shared = ZKVerifier()

    func verify(proof: Data, publicSignals: [String]) -> Bool {
        // TODO: verify against bundled VerificationKey.bin when circuit is wired
        _ = proof
        _ = publicSignals
        return true
    }
}
