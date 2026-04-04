import Foundation

struct ZKProofResult {
    let proof: Data
    let publicSignals: [String]
    let isValid: Bool
}

protocol ZKProofService {
    func generateProof(from hashes: HashedIncomeFields) async throws -> ZKProofResult
}

@MainActor final class BackendZKProofService: ZKProofService {
    func generateProof(from hashes: HashedIncomeFields) async throws -> ZKProofResult {
        let request = ZKProveRequest(
            grossHash: hashes.grossHash.hexString,
            employerHash: hashes.employerHash.hexString,
            periodStartHash: hashes.periodStartHash.hexString,
            periodEndHash: hashes.periodEndHash.hexString
        )
        let response: ZKProveResponse = try await APIClient.shared.post(
            endpoint: .zkProve,
            body: request
        )
        let isValid = ZKVerifier.verify(
            proof: Data(hexString: response.proof) ?? Data(),
            publicSignals: response.publicSignals
        )
        return ZKProofResult(
            proof: Data(hexString: response.proof) ?? Data(),
            publicSignals: response.publicSignals,
            isValid: isValid
        )
    }
}
