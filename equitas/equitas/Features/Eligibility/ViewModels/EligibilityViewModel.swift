import SwiftUI

enum VerificationStep {
    case worldID
    case incomeVerification
    case processing
    case complete
    case failed(Error)
}

enum ProcessingStatus {
    case pending, inProgress, complete, failed
}

@Observable
@MainActor
final class EligibilityViewModel {
    var currentStep: VerificationStep = .worldID
    var worldIDConnectorURL: URL? = nil
    var isProvingIncome = false

    // Processing sub-step statuses
    var walletStatus: ProcessingStatus = .pending
    var circlesStatus: ProcessingStatus = .pending
    var nftStatus: ProcessingStatus = .pending
    var tokenStatus: ProcessingStatus = .pending

    // Held in memory only — never persisted
    private var worldIDProof: WorldIDProof?
    private var zkProofResult: ZKProofResult?

    var stepIndex: Int {
        switch currentStep {
        case .worldID: return 0
        case .incomeVerification: return 1
        case .processing, .complete, .failed: return 2
        }
    }

    func startWorldIDVerification() async {
        let service = WorldIDService()
        do {
            let (url, proof) = try await service.startVerification()
            worldIDConnectorURL = url
            worldIDProof = proof
            currentStep = .incomeVerification
        } catch {
            currentStep = .failed(error)
        }
    }

    func startDocumentScan() async {
        let scanner = DocumentScannerService()
        let hasher = IncomeHashingService()
        let prover = BackendZKProofService()
        do {
            let fields = try await scanner.scanPaystub()
            isProvingIncome = true
            let hashes = hasher.hash(fields)
            zkProofResult = try await prover.generateProof(from: hashes)
            isProvingIncome = false
            currentStep = .processing
        } catch {
            isProvingIncome = false
            currentStep = .failed(error)
        }
    }

    func startBankLink() async {
        // TODO: implement Plaid/MX OAuth bank link flow
    }

    func runBlockchainOrchestration() async {
        let walletService = WalletService()
        let circlesService = CirclesWalletService()
        let hederaService = HederaService()
        let snapService = SNAPtokenService()

        do {
            walletStatus = .inProgress
            let wallet = try await walletService.createOrLoadWallet()
            walletStatus = .complete

            circlesStatus = .inProgress
            try await circlesService.registerWallet(wallet)
            circlesStatus = .complete

            nftStatus = .inProgress
            let nftResult = try await hederaService.mintEligibilityNFT(wallet: wallet)
            nftStatus = .complete

            tokenStatus = .inProgress
            try await snapService.issueInitialTokens(to: wallet.address, nftSerial: nftResult.serialNumber)
            tokenStatus = .complete

            currentStep = .complete
        } catch {
            currentStep = .failed(error)
        }
    }
}
