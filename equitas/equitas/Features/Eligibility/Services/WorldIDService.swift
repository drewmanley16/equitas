import Foundation

struct WorldIDProof {
    let nullifierHash: String
    let merkleRoot: String
    let proof: String
    let verificationLevel: String
}

actor WorldIDService {
    func startVerification() async throws -> (URL, WorldIDProof) {
        // TODO: fetch RP context from backend, init IDKit, poll for completion
        // Placeholder until idkit-swift SPM package is added
        let url = URL(string: "https://worldcoin.org/verify")!
        let proof = WorldIDProof(
            nullifierHash: "",
            merkleRoot: "",
            proof: "",
            verificationLevel: "orb"
        )
        return (url, proof)
    }
}
