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

                // Logo mark
                ZStack {
                    Circle()
                        .fill(EquitasTheme.purple.opacity(0.25))
                        .blur(radius: 30)
                        .frame(width: 160, height: 160)
                    Circle()
                        .strokeBorder(EquitasTheme.goldGradient, lineWidth: 1.5)
                        .frame(width: 110, height: 110)
                    Image(systemName: "seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(EquitasTheme.goldGradient)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .goldGlow(radius: 28)
                .padding(.bottom, 32)

                // Wordmark
                VStack(spacing: 6) {
                    Text("EQUITAS")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    Text("Benefits, verified on-chain.")
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                        .tracking(1)
                }
                .opacity(logoOpacity)
                .padding(.bottom, 16)

                // Pill badges
                HStack(spacing: 10) {
                    BadgePill(label: "World ID")
                    BadgePill(label: "ZK Proof")
                    BadgePill(label: "Hedera NFT")
                }
                .opacity(logoOpacity)

                Spacer()
                Spacer()

                // Auth actions
                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.handleRequest(request)
                    } onCompletion: { result in
                        Task { await viewModel.handleCompletion(result, appState: appState) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(EquitasTheme.glassStroke, lineWidth: 1)
                    )

                    Text("Your data never leaves your device.")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
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

private struct BadgePill: View {
    let label: String
    var body: some View {
        Text(label)
            .font(EquitasTheme.captionFont)
            .foregroundStyle(EquitasTheme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(EquitasTheme.gold.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(EquitasTheme.gold.opacity(0.3), lineWidth: 1))
    }
}
