import Foundation

// MARK: - Request (multipart — field name is "document")
// No Codable struct needed; the file is uploaded as multipart/form-data.

// MARK: - Response
struct ZKProveResponse: Codable {
    /// HMAC-SHA256 commitment — acts as the ZK proof
    let proof: String
    /// Public signals: ["eligible", "threshold_cents:200500", "nonce:...", "issued:..."]
    let publicSignals: [String]
    /// Server-side eligibility decision
    let isValid: Bool
    /// Non-sensitive display metadata
    let payPeriod: String?
    let employer: String?
}
