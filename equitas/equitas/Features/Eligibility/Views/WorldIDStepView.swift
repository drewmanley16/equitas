import SwiftUI

struct WorldIDStepView: View {
    let viewModel: EligibilityViewModel
    @Environment(AppState.self) private var appState
    @State private var showOIDCSafari = false

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
                    WaitingForScanView(showSafari: $showOIDCSafari)

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
        // Open SFSafariViewController with World ID's hosted verification page
        .sheet(isPresented: $showOIDCSafari) {
            if let url = viewModel.oidcURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        // Receive OIDC callback from equitasApp.onOpenURL
        .onChange(of: appState.pendingOIDCCallback) { _, url in
            guard let url else { return }
            showOIDCSafari = false          // dismiss SFSafariViewController
            appState.pendingOIDCCallback = nil
            Task { await viewModel.handleOIDCCallback(url: url) }
        }
    }
}

// MARK: - Waiting for scan
private struct WaitingForScanView: View {
    @Binding var showSafari: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Open World ID hosted page — shows its own QR code
            PrimaryButton(title: "Verify with World ID", icon: "globe", style: .gold) {
                showSafari = true
            }

            Text("A browser will open showing a QR code.\nScan it with the World App on any device.")
                .font(EquitasTheme.captionFont)
                .foregroundStyle(EquitasTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
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
        ("1", "Tap \"Verify with World ID\" to open the verification page"),
        ("2", "Scan the QR code with World App on any device"),
        ("3", "World App generates a ZK proof — your data stays private"),
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
