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
    var worldIDState: WorldIDState    = .idle
    var isProvingIncome               = false

    /// The World ID OIDC URL — open this in SFSafariViewController
    var oidcURL: URL?

    // Processing sub-step statuses
    var walletStatus:  ProcessingStatus = .pending
    var circlesStatus: ProcessingStatus = .pending
    var nftStatus:     ProcessingStatus = .pending
    var tokenStatus:   ProcessingStatus = .pending

    // Held in memory only — never persisted
    private var worldIDProof:  WorldIDOIDCExchangeResponse?
    private var zkProofResult: ZKProofResult?
    private var activeNonce:   String?
    private var codeVerifier:  String?
    private let service = WorldIDService()

    var stepIndex: Int {
        switch currentStep {
        case .worldID: return 0
        case .incomeVerification: return 1
        case .processing, .complete, .failed: return 2
        }
    }

    // MARK: - World ID OIDC

    /// Generates PKCE pair, builds OIDC URL, sets state to .waitingForScan.
    /// The view should then show a button to open oidcURL in SFSafariViewController.
    func startWorldIDVerification() async {
        worldIDState = .fetchingContext

        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let (verifier, challenge) = service.generatePKCE()

        activeNonce  = nonce
        codeVerifier = verifier
        guard let url = service.oidcAuthorizeURL(nonce: nonce, codeChallenge: challenge) else {
            worldIDState = .failed(WorldIDError.contextFetchFailed)
            return
        }
        oidcURL      = url
        worldIDState = .waitingForScan
    }

    /// Called by the view when equitas://worldid-oidc-callback is received.
    func handleOIDCCallback(url: URL) async {
        guard let (code, state) = service.parseOIDCCallback(url),
              let verifier = codeVerifier,
              state == activeNonce else { return }

        worldIDState = .verifying
        do {
            let response = try await service.exchangeOIDCCode(
                code: code, nonce: state, codeVerifier: verifier
            )
            guard response.verified else { throw WorldIDError.verificationFailed }
            worldIDProof = response
            // Zero out sensitive PKCE material
            codeVerifier = nil
            worldIDState = .verified
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 s to show ✓
            currentStep  = .incomeVerification
        } catch {
            worldIDState = .failed(error)
        }
    }

    // MARK: - Income ZK proof

    func startDocumentScan() async {
        let scanner = DocumentScannerService()
        let hasher  = IncomeHashingService()
        let prover  = BackendZKProofService()
        do {
            let fields = try await scanner.scanPaystub()
            isProvingIncome = true
            let hashes = hasher.hash(fields)
            let result = try await prover.generateProof(from: hashes)
            isProvingIncome = false
            guard result.isValid else {
                throw ZKProofError.invalidProof
            }
            zkProofResult = result
            currentStep = .processing
        } catch {
            isProvingIncome = false
            currentStep = .failed(error)
        }
    }

    func startBankLink() async {
        // TODO: implement Plaid/MX OAuth bank link flow
    }

    // MARK: - Blockchain orchestration

    func runBlockchainOrchestration() async {
        let walletService  = WalletService()
        let circlesService = CirclesWalletService()
        let hederaService  = HederaService()
        let snapService    = SNAPtokenService()

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
        case .fetchingContext: return "Preparing verification…"
        case .waitingForScan:  return "Ready — tap to verify"
        case .verifying:       return "Verifying proof…"
        case .verified:        return "Identity verified!"
        case .failed:          return "Verification failed"
        }
    }
}

enum ZKProofError: Error, LocalizedError {
    case invalidProof
    var errorDescription: String? { "Income proof could not be verified." }
}
