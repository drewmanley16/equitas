import SwiftUI
import IDKit

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
    var currentStep:     VerificationStep = .worldID
    var worldIDState:    WorldIDState     = .idle
    var isProvingIncome                   = false
    var zkEmployer:   String?             = nil
    var zkPayPeriod:  String?             = nil

    /// URL shown as QR code and opened by the "Open World App" button
    var verificationURL: URL?

    // Processing sub-step statuses
    var walletStatus:  ProcessingStatus = .pending
    var circlesStatus: ProcessingStatus = .pending
    var nftStatus:              ProcessingStatus = .pending
    var benefitsFundingStatus:  ProcessingStatus = .pending

    // In-memory only
    private var worldIDProof:  WorldIDProof?
    private var zkProofResult: ZKProofResult?
    private var activeNonce:   String?
    private var activeRequest: IDKitRequest?
    private var verificationTask: Task<Void, Never>?
    private let service = WorldIDService()

    var stepIndex: Int {
        switch currentStep {
        case .worldID: return 0
        case .incomeVerification: return 1
        case .processing, .complete, .failed: return 2
        }
    }

    // MARK: - World ID

    func startWorldIDVerification() async {
        guard case .worldID = currentStep else { return }
        if case .fetchingContext = worldIDState { return }
        if case .waitingForScan = worldIDState { return }
        if case .verifying = worldIDState { return }

        verificationTask?.cancel()
        verificationTask = nil
        activeRequest = nil
        worldIDState = .fetchingContext
        do {
            let verification = try await service.startVerification()
            activeNonce = verification.nonce
            verificationURL = verification.connectorURL
            activeRequest = verification.request
            worldIDState = .waitingForScan
            waitForWorldIDCompletion(using: verification.request)
        } catch {
            worldIDState = .failed(error)
        }
    }

    /// Called when equitas://worldid-callback arrives via onOpenURL
    func handleCallback(url: URL) async {
        guard url.scheme == "equitas", url.host == "worldid-callback" else { return }

        if let proof = service.parseCallback(url),
           let nonce = activeNonce {
            verificationTask?.cancel()
            verificationTask = nil
            await completeWorldIDVerification(with: proof, nonce: nonce, shouldVerifyOnBackend: true)
            return
        }

        resumeWorldIDVerificationIfNeeded()
    }

    func resumeWorldIDVerificationIfNeeded() {
        guard case .waitingForScan = worldIDState,
              verificationTask == nil,
              let activeRequest else { return }

        waitForWorldIDCompletion(using: activeRequest)
    }

    // MARK: - Income ZK proof

    /// Primary path: user picks a PDF paystub — backend parses + proves eligibility.
    func uploadDocument(url: URL) async {
        isProvingIncome = true
        do {
            let prover = DocumentZKProofService()
            let result = try await prover.prove(documentURL: url)
            isProvingIncome = false
            zkEmployer  = result.employer
            zkPayPeriod = result.payPeriod
            zkProofResult = result
            currentStep = .processing
        } catch {
            isProvingIncome = false
            currentStep = .failed(error)
        }
    }

    /// Placeholder — camera scanning not yet implemented.
    func startDocumentScan() async {
        currentStep = .failed(DocumentScannerError.scanningNotAvailable)
    }

    func startBankLink() async {
        // TODO: Plaid/MX OAuth
    }

    // MARK: - Blockchain orchestration

    func runBlockchainOrchestration() async {
        let walletService  = WalletService()
        let circlesService = CirclesWalletService()
        let hederaService   = HederaService()
        let benefitsService = SNAPBenefitsService()

        guard let proofHash = currentProofHash else {
            currentStep = .failed(EligibilityAttestationError.missingIncomeProof)
            return
        }
        guard let worldIDNullifier = currentWorldIDNullifier else {
            currentStep = .failed(EligibilityAttestationError.missingWorldIDNullifier)
            return
        }

        do {
            walletStatus = .inProgress
            let wallet = try await walletService.createOrLoadWallet()
            walletStatus = .complete

            circlesStatus = .inProgress
            try await circlesService.registerWallet(wallet)
            circlesStatus = .complete

            nftStatus = .inProgress
            let nftResult = try await hederaService.mintEligibilityNFT(
                wallet: wallet,
                proofHash: proofHash,
                worldIDNullifier: worldIDNullifier
            )
            nftStatus = .complete

            benefitsFundingStatus = .inProgress
            try await benefitsService.fundBenefitsAfterEligibility(
                walletAddress: wallet.address,
                nftSerial: nftResult.serialNumber,
                proofHash: proofHash
            )
            benefitsFundingStatus = .complete

            currentStep = .complete
        } catch {
            currentStep = .failed(error)
        }
    }

    private func waitForWorldIDCompletion(using request: IDKitRequest) {
        verificationTask?.cancel()
        verificationTask = Task { [weak self] in
            guard let self else { return }

            let completion = await request.pollUntilCompletion(
                options: IDKitPollOptions(
                    pollIntervalMs: 1_000,
                    timeoutMs: 180_000
                )
            )

            switch completion {
            case .success(let result):
                await self.completeWorldIDVerification(with: result)
            case .failure(let error):
                if error == .cancelled {
                    await MainActor.run {
                        self.verificationTask = nil
                    }
                    return
                }
                await MainActor.run {
                    self.verificationTask = nil
                    self.activeRequest = nil
                    self.worldIDState = .failed(self.worldIDError(from: error))
                }
            }
        }
    }

    private func completeWorldIDVerification(
        with proof: WorldIDProof,
        nonce: String,
        shouldVerifyOnBackend: Bool
    ) async {
        verificationTask = nil
        activeRequest = nil
        worldIDState = .verifying

        do {
            if shouldVerifyOnBackend {
                _ = try await service.verifyOnBackend(proof: proof, nonce: nonce)
            }
            worldIDProof = proof
            worldIDState = .verified
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            currentStep = .incomeVerification
        } catch {
            worldIDState = .failed(error)
        }
    }

    private func completeWorldIDVerification(with result: IDKitResult) async {
        verificationTask = nil
        activeRequest = nil
        worldIDState = .verifying

        do {
            _ = try await service.verifyOnBackend(result: result)
            if let nullifier = worldIDNullifier(from: result) {
                worldIDProof = WorldIDProof(
                    nullifierHash: nullifier,
                    merkleRoot: "",
                    proof: "",
                    verificationLevel: WorldIDConfig.verificationLevel
                )
            }
            worldIDState = .verified
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            currentStep = .incomeVerification
        } catch {
            worldIDState = .failed(error)
        }
    }

    private func worldIDError(from error: IDKitErrorCode) -> Error {
        switch error {
        case .timeout:
            return WorldIDError.pollingTimeout
        case .cancelled:
            return WorldIDError.cancelled
        default:
            return WorldIDError.verificationFailed
        }
    }

    private var currentProofHash: String? {
        guard let zkProofResult else { return nil }
        let value = String(decoding: zkProofResult.proof, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var currentWorldIDNullifier: String? {
        guard let nullifier = worldIDProof?.nullifierHash else { return nil }
        let value = nullifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return value
    }

    private func worldIDNullifier(from result: IDKitResult) -> String? {
        for response in result.responses {
            switch response {
            case .v4(_, _, _, _, let nullifier, _):
                if !nullifier.isEmpty { return nullifier }
            case .v3(_, _, _, _, let nullifier):
                if !nullifier.isEmpty { return nullifier }
            case .session:
                continue
            }
        }
        return nil
    }
}

// MARK: - Supporting types

enum WorldIDState: Equatable {
    case idle
    case fetchingContext
    case waitingForScan
    case verifying
    case verified
    case failed(Error)

    static func == (lhs: WorldIDState, rhs: WorldIDState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.fetchingContext, .fetchingContext),
             (.waitingForScan, .waitingForScan), (.verifying, .verifying),
             (.verified, .verified): return true
        case (.failed, .failed): return true
        default: return false
        }
    }

    var statusLabel: String {
        switch self {
        case .idle:            return ""
        case .fetchingContext: return "Preparing…"
        case .waitingForScan:  return "Waiting for World App scan"
        case .verifying:       return "Verifying proof…"
        case .verified:        return "Identity verified!"
        case .failed:          return "Verification failed"
        }
    }
}

enum EligibilityAttestationError: LocalizedError {
    case missingIncomeProof
    case missingWorldIDNullifier

    var errorDescription: String? {
        switch self {
        case .missingIncomeProof:
            return "Income proof is missing, so the Hedera eligibility NFT could not be minted."
        case .missingWorldIDNullifier:
            return "World ID verification is missing a nullifier, so the Hedera eligibility NFT could not be minted."
        }
    }
}
