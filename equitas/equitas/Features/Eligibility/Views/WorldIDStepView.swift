import SwiftUI

struct WorldIDStepView: View {
    let viewModel: EligibilityViewModel

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
                    WaitingForScanView(viewModel: viewModel)

                case .verifying:
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(EquitasTheme.gold)
                            .scaleEffect(1.4)
                        Text("Verifying your proof on-chain…")
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
        .onDisappear { viewModel.cancelWorldIDPolling() }
    }
}

// MARK: - Waiting for scan: deep link + QR fallback
private struct WaitingForScanView: View {
    let viewModel: EligibilityViewModel
    @State private var showQR = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            // Primary: open World App on this device
            if let deepLink = viewModel.worldIDDeepLinkURL {
                PrimaryButton(title: "Open World App", icon: "globe", style: .gold) {
                    openURL(deepLink)
                }
            }

            // Secondary: show QR for scanning from another device
            Button {
                withAnimation(.spring(response: 0.4)) { showQR.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showQR ? "chevron.up" : "qrcode")
                        .font(.system(size: 13))
                    Text(showQR ? "Hide QR Code" : "Scan from another device")
                        .font(EquitasTheme.captionFont)
                }
                .foregroundStyle(EquitasTheme.textSecondary)
            }

            if showQR, let url = viewModel.worldIDConnectorURL {
                VStack(spacing: 10) {
                    QRCodeView(content: url.absoluteString)
                        .frame(width: 200, height: 200)
                        .purpleGlow(radius: 16)
                    Text("Scan with World App")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Polling indicator
            HStack(spacing: 8) {
                ProgressView()
                    .tint(EquitasTheme.purple)
                    .scaleEffect(0.8)
                Text("Listening for verification…")
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
            }
            .padding(.top, 4)
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

// MARK: - How it works card
private struct HowItWorksCard: View {
    private let steps: [(String, String)] = [
        ("1", "Open World App or scan the QR code"),
        ("2", "World App generates a ZK proof of your iris scan"),
        ("3", "Proof is verified on-chain — your data stays private"),
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
