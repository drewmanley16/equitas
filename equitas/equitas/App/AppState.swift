import SwiftUI

enum AuthState {
    case unauthenticated
    case lockedAuthenticated
    case unlocked
}

enum EligibilityStatus {
    case notStarted
    case inProgress
    case complete
}

@Observable
@MainActor
final class AppState {
    var authState: AuthState = .unauthenticated
    var eligibilityStatus: EligibilityStatus = .notStarted
    var walletAddress: String? = nil

    var isEligibilityComplete: Bool {
        eligibilityStatus == .complete
    }
}
