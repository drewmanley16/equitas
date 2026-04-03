import SwiftUI

struct AppRouter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.authState {
        case .unauthenticated:
            AuthGateView()
        case .lockedAuthenticated:
            BiometricLockView()
        case .unlocked:
            if appState.isEligibilityComplete {
                MainTabView()
            } else {
                EligibilityRootView()
            }
        }
    }
}
