import SwiftUI
import AuthenticationServices

struct AuthGateView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            CosmicBackground()

            VStack(spacing: 0) {
                Spacer()

                Text("EQUITAS")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(EquitasTheme.textPrimary)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .padding(.bottom, 16)

                .opacity(logoOpacity)

                Spacer()
                Spacer()

                // Auth actions
                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.handleRequest(request)
                    } onCompletion: { result in
                        viewModel.handleCompletion(result, appState: appState)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(EquitasTheme.glassStroke, lineWidth: 1)
                    )

                    #if DEBUG
                    Button("Demo Mode (Simulator)") {
                        viewModel.signInWithDemoMode(appState: appState)
                    }
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.gold.opacity(0.7))
                    #endif

                    if let error = viewModel.error {
                        Text(error)
                            .font(EquitasTheme.captionFont)
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, EquitasTheme.screenPadding)
                .padding(.bottom, 52)
                .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}
