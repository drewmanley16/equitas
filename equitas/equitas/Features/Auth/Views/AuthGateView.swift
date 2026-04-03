import SwiftUI
import AuthenticationServices

struct AuthGateView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            VStack(spacing: 8) {
                Text("Equitas")
                    .font(.largeTitle.bold())
                Text("SNAP Benefits Verification")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                viewModel.handleRequest(request)
            } onCompletion: { result in
                Task { await viewModel.handleCompletion(result, appState: appState) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
