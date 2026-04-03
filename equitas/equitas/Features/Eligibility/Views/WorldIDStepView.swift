import SwiftUI

struct WorldIDStepView: View {
    let viewModel: EligibilityViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.openURL)    private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(EquitasTheme.purple.opacity(0.2))
                            .blur(radius: 20)
                            .frame(width: 120)
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(EquitasTheme.goldGradient)
                            .goldGlow(radius: 16)
                    }
                    Text("Proof of Humanity")
                        .font(EquitasTheme.titleFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    Text("Verify you're a unique real person with World ID.\nNo personal data is stored or shared.")
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Status badge
                StatusBadge(state: viewModel.worldIDState)

                // Main action area
                switch viewModel.worldIDState {
                case .idle, .fetchingContext:
                    ProgressView()
                        .tint(EquitasTheme.gold)
                        .scaleEffect(1.2)
                        .frame(height: 80)

                case .waitingForScan:
                    if let url = viewModel.verificationURL {
                        VerifyOptionsView(url: url, openURL: openURL)
                    }

                case .verifying:
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(EquitasTheme.gold)
                            .scaleEffect(1.4)
                        Text("Verifying your proof…")
                            .font(EquitasTheme.bodyFont)
                            .foregroundStyle(EquitasTheme.textSecondary)
                    }
                    .frame(height: 120)

                case .verified:
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(EquitasTheme.goldGradient)
                            .goldGlow(radius: 20)
                            .symbolEffect(.bounce)
                        Text("Identity Verified")
                            .font(EquitasTheme.headlineFont)
                            .foregroundStyle(EquitasTheme.gold)
                    }
                    .frame(height: 120)

                case .failed(let error):
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                        Text(error.localizedDescription)
                            .font(EquitasTheme.bodyFont)
                            .foregroundStyle(EquitasTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        PrimaryButton(title: "Try Again", style: .ghost) {
                            Task { await viewModel.startWorldIDVerification() }
                        }
                    }
                }

                // How it works
                HowItWorksCard()
            }
            .padding(.horizontal, EquitasTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .task { await viewModel.startWorldIDVerification() }
        .onChange(of: appState.pendingWorldIDCallback) { _, url in
            guard let url else { return }
            appState.pendingWorldIDCallback = nil
            Task { await viewModel.handleCallback(url: url) }
        }
    }
}

// MARK: - Two verification options: QR code + button

private struct VerifyOptionsView: View {
    let url: URL
    let openURL: OpenURLAction
    @State private var showQR = true

    var body: some View {
        VStack(spacing: 20) {

            // Option 1: QR code (scan with World App from any device)
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "qrcode")
                        .foregroundStyle(EquitasTheme.purple)
                    Text("Scan with World App")
                        .font(EquitasTheme.headlineFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                }

                if showQR {
                    QRCodeView(content: url.absoluteString)
                        .frame(width: 200, height: 200)
                        .purpleGlow(radius: 16)
                        .transition(.scale.combined(with: .opacity))
                }

                Button {
                    withAnimation(.spring(response: 0.35)) { showQR.toggle() }
                } label: {
                    Text(showQR ? "Hide QR" : "Show QR")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                }
            }
            .padding(EquitasTheme.cardPadding)
            .glassCard()

            // Divider
            HStack {
                Rectangle().fill(EquitasTheme.textSecondary.opacity(0.3)).frame(height: 1)
                Text("or").font(EquitasTheme.captionFont).foregroundStyle(EquitasTheme.textSecondary)
                Rectangle().fill(EquitasTheme.textSecondary.opacity(0.3)).frame(height: 1)
            }

            // Option 2: Open World App directly (same device)
            PrimaryButton(title: "Authorize with World ID", icon: "globe", style: .gold) {
                openURL(url)
            }

            Text("Opens World App if installed, or worldcoin.org in your browser.")
                .font(EquitasTheme.captionFont)
                .foregroundStyle(EquitasTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Status badge

private struct StatusBadge: View {
    let state: WorldIDState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .shadow(color: dotColor.opacity(0.8), radius: 4)
            Text(state.statusLabel)
                .font(EquitasTheme.captionFont)
                .foregroundStyle(EquitasTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .glassCard()
        .animation(.easeInOut, value: state)
    }

    private var dotColor: Color {
        switch state {
        case .verified:       return .green
        case .failed:         return .red
        case .verifying:      return EquitasTheme.gold
        case .waitingForScan: return EquitasTheme.purple
        default:              return EquitasTheme.textSecondary
        }
    }
}

// MARK: - How it works

private struct HowItWorksCard: View {
    private let steps: [(String, String)] = [
        ("1", "Scan the QR with World App — or tap the button to open World App"),
        ("2", "World App generates a ZK proof of your iris scan"),
        ("3", "Proof verified on-chain — your data stays private"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How it works")
                .font(EquitasTheme.headlineFont)
                .foregroundStyle(EquitasTheme.textPrimary)

            ForEach(steps, id: \.0) { number, label in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(EquitasTheme.purple.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Text(number)
                            .font(EquitasTheme.captionFont)
                            .foregroundStyle(EquitasTheme.purple)
                    }
                    Text(label)
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
    }
}
