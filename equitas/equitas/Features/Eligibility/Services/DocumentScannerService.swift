import VisionKit
import Vision
import UIKit

actor DocumentScannerService {
    func scanPaystub() async throws -> IncomeFields {
        // TODO: present VNDocumentCameraViewController, run VNRecognizeTextRequest
        // Placeholder returning test data
        return IncomeFields(
            grossCents: 200000,
            employerName: "ACME Corp",
            periodStart: Date().addingTimeInterval(-1_209_600),
            periodEnd: Date()
        )
    }
}
