import SwiftUI

enum AuthState {
    case unauthenticated       // no Apple ID on file — show sign-in
    case lockedAuthenticated   // returning user, needs Face ID
    case unlocked              // in the app
}

enum EligibilityStatus {
    case notStarted
    case inProgress
    case complete
}

@Observable
@MainActor
final class AppState {
    var authState: AuthState
    var eligibilityStatus: EligibilityStatus = .notStarted
    var walletAddress: String? = nil
    /// Set by equitasApp.onOpenURL when World App returns a legacy return_to proof
    var pendingWorldIDCallback: URL? = nil
    /// Set by equitasApp.onOpenURL when World ID OIDC redirects with authorization code
    var pendingOIDCCallback: URL? = nil

    init() {
        // Returning user: Apple ID is already stored → require Face ID to unlock
        if KeychainService().load(forKey: "appleUserID") != nil {
            authState = .lockedAuthenticated
        } else {
            authState = .unauthenticated
        }
    }

    var isEligibilityComplete: Bool {
        eligibilityStatus == .complete
    }
}
