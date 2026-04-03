import Foundation

struct ZKProveRequest: Codable {
    let grossHash: String
    let employerHash: String
    let periodStartHash: String
    let periodEndHash: String
}

struct ZKProveResponse: Codable {
    let proof: String
    let publicSignals: [String]
}
