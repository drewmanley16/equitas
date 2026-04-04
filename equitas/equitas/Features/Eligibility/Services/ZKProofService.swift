import Foundation
import UniformTypeIdentifiers

struct ZKProofResult {
    let proof: Data
    let publicSignals: [String]
    let isValid: Bool
    let employer: String?
    let payPeriod: String?
}

protocol ZKProofService {
    func generateProof(from hashes: HashedIncomeFields) async throws -> ZKProofResult
}

// MARK: - Document upload prover (primary path)

@MainActor final class DocumentZKProofService {
    /// Upload a paystub PDF to the backend for parsing and ZK proof generation.
    func prove(documentURL: URL) async throws -> ZKProofResult {
        // Security-scoped access is required for files from the document picker
        let accessed = documentURL.startAccessingSecurityScopedResource()
        defer { if accessed { documentURL.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: documentURL)
        let mimeType = mimeType(for: documentURL)
        let fileName = documentURL.lastPathComponent

        let response: ZKProveResponse = try await APIClient.shared.upload(
            endpoint: .zkProve,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType
        )

        guard response.isValid else { throw ZKProofError.ineligible }

        return ZKProofResult(
            proof: Data(response.proof.utf8),
            publicSignals: response.publicSignals,
            isValid: response.isValid,
            employer: response.employer,
            payPeriod: response.payPeriod
        )
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/pdf"
    }
}

// MARK: - Legacy hash-based prover (kept for reference)

@MainActor final class BackendZKProofService: ZKProofService {
    func generateProof(from hashes: HashedIncomeFields) async throws -> ZKProofResult {
        // Legacy path — not used in the current document-upload flow
        throw ZKProofError.legacyPathUnsupported
    }
}

// MARK: - Errors

enum ZKProofError: Error, LocalizedError {
    case invalidProof
    case ineligible
    case legacyPathUnsupported

    var errorDescription: String? {
        switch self {
        case .invalidProof:          return "Income proof could not be verified."
        case .ineligible:            return "Based on your paystub, your income exceeds the SNAP eligibility limit."
        case .legacyPathUnsupported: return "Use the document upload path."
        }
    }
}
