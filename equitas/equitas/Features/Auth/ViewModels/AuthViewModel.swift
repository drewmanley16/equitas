import AuthenticationServices

@Observable
@MainActor
final class AuthViewModel {
    var error: Error?

    func handleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleCompletion(
        _ result: Result<ASAuthorization, Error>,
        appState: AppState
    ) async {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let authService = AuthService()
            do {
                try await authService.signIn(with: credential)
                appState.authState = .unlocked
            } catch {
                self.error = error
            }
        case .failure(let err):
            self.error = err
        }
    }
}
