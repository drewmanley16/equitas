import Foundation

enum DocumentScannerError: Error, LocalizedError {
    case scanningNotAvailable

    var errorDescription: String? {
        "Camera scanning is coming soon. Please use 'Upload from Files' instead."
    }
}

/// Placeholder — VNDocumentCameraViewController integration is pending.
/// The primary income verification path is document upload via DocumentZKProofService.
actor DocumentScannerService {
    func scanPaystub() async throws -> IncomeFields {
        throw DocumentScannerError.scanningNotAvailable
    }
}
