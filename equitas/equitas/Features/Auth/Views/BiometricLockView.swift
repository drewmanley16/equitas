import SwiftUI

struct BiometricLockView: View {
    @Environment(AppState.self) private var appState
    @State private var ringScale: CGFloat = 0.9
    @State private var ringOpacity: CGFloat = 0.4

    var body: some View {
        ZStack {
            CosmicBackground()

            VStack(spacing: 36) {
                Spacer()

                // Animated ring + icon
                ZStack {
                    Circle()
                        .strokeBorder(EquitasTheme.purple.opacity(0.3), lineWidth: 1)
                        .frame(width: 160)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: ringScale)
                    Circle()
                        .strokeBorder(EquitasTheme.goldGradient, lineWidth: 1.5)
                        .frame(width: 112)
                    Image(systemName: "faceid")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundStyle(EquitasTheme.goldGradient)
                        .goldGlow(radius: 16)
                }
                .purpleGlow(radius: 30)

                VStack(spacing: 8) {
                    Text("Unlock Equitas")
                        .font(EquitasTheme.titleFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    Text("Authenticate to access your wallet")
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                }

                Spacer()

                PrimaryButton(title: "Use Face ID", icon: "faceid", style: .gold) {
                    Task { await unlock() }
                }
                .padding(.horizontal, EquitasTheme.screenPadding)
                .padding(.bottom, 52)
            }
        }
        .task { await unlock() }
        .onAppear {
            withAnimation { ringScale = 1.1; ringOpacity = 0.15 }
        }
    }

    private func unlock() async {
        let service = BiometricService()
        if (try? await service.authenticate()) == true {
            appState.authState = .unlocked
        }
    }
}
