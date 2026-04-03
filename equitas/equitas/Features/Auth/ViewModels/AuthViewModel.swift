import AuthenticationServices

@Observable
@MainActor
final class AuthViewModel {
    var error: String?

    func handleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleCompletion(
        _ result: Result<ASAuthorization, Error>,
        appState: AppState
    ) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                error = "Invalid credential type."
                return
            }
            let authService = AuthService()
            do {
                try authService.signIn(with: credential)
                // Go to Face ID lock screen — BiometricLockView auto-triggers
                appState.authState = .lockedAuthenticated
            } catch {
                self.error = error.localizedDescription
            }
        case .failure(let err):
            // Ignore cancellation (user dismissed the sheet)
            let code = (err as? ASAuthorizationError)?.code
            if code != .canceled {
                self.error = err.localizedDescription
            }
        }
    }

    /// DEBUG only — bypasses Apple ID for simulator testing
    func signInWithDemoMode(appState: AppState) {
        appState.authState = .lockedAuthenticated
    }
}
