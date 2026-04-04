import SwiftUI

struct WorldIDStepView: View {
    let viewModel: EligibilityViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 24) {
            Text("Authorize with World ID")
                .font(EquitasTheme.titleFont)
                .foregroundStyle(EquitasTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch viewModel.worldIDState {
            case .idle, .fetchingContext:
                MinimalLoadingCard(title: "Preparing World ID")
            case .waitingForScan:
                if let url = viewModel.verificationURL {
                    VerifyOptionsView(url: url, openURL: openURL)
                }
            case .verifying:
                MinimalLoadingCard(title: "Authorizing")
            case .verified:
                MinimalSuccessCard(title: "World ID approved")
            case .failed(let error):
                MinimalFailureCard(message: error.localizedDescription) {
                    Task { await viewModel.startWorldIDVerification() }
                }
            }
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
        .task { await viewModel.startWorldIDVerification() }
        .onChange(of: appState.pendingWorldIDCallback) { _, url in
            guard let url else { return }
            appState.pendingWorldIDCallback = nil
            Task { await viewModel.handleCallback(url: url) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            viewModel.resumeWorldIDVerificationIfNeeded()
        }
    }
}

private struct VerifyOptionsView: View {
    let url: URL
    let openURL: OpenURLAction
    @State private var showQR = true

    var body: some View {
        VStack(spacing: 20) {
            if showQR {
                QRCodeView(content: url.absoluteString)
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
            }

            PrimaryButton(title: "Authorize with World ID", icon: "globe", style: .gold) {
                openURL(url)
            }

            Button {
                withAnimation(.spring(response: 0.35)) { showQR.toggle() }
            } label: {
                Text(showQR ? "Hide QR" : "Show QR")
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
            }

            Text("Scan the QR or open World ID on this device.")
                .font(EquitasTheme.captionFont)
                .foregroundStyle(EquitasTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
