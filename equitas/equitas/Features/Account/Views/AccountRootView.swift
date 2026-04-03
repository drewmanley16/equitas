import SwiftUI

struct AccountRootView: View {
    @Environment(AppState.self) private var appState
    @State private var shimmerOffset: CGFloat = -200
    private let walletAddress = "0x4f3A…9c12"

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // NFT eligibility card
                    EligibilityNFTCard(shimmerOffset: shimmerOffset)
                        .padding(.top, 8)
                        .onAppear {
                            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                                shimmerOffset = 400
                            }
                        }

                    // Wallet address
                    WalletAddressCard(address: walletAddress)

                    // Linked programs
                    LinkedProgramsCard()
                }
                .padding(.horizontal, EquitasTheme.screenPadding)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Account")
                    .font(EquitasTheme.headlineFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
            }
        }
    }
}

// MARK: - Holographic NFT card
struct EligibilityNFTCard: View {
    let shimmerOffset: CGFloat

    var body: some View {
        ZStack {
            // Base gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.08, blue: 0.40),
                            Color(red: 0.06, green: 0.02, blue: 0.18),
                            Color(red: 0.10, green: 0.05, blue: 0.25),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            // Shimmer
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120, height: 200)
                .offset(x: shimmerOffset)
                .clipped()

            // Border
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [EquitasTheme.gold.opacity(0.7), EquitasTheme.purple.opacity(0.5), EquitasTheme.gold.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SNAP ELIGIBILITY")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(3)
                            .foregroundStyle(EquitasTheme.gold.opacity(0.8))
                        Text("Verified")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(EquitasTheme.textPrimary)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(EquitasTheme.gold.opacity(0.15)).frame(width: 52)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(EquitasTheme.goldGradient)
                            .goldGlow(radius: 12)
                    }
                }
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HEDERA NFT")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(EquitasTheme.textSecondary)
                        Text("#0.0.4821 / Serial 7")
                            .font(EquitasTheme.monoFont)
                            .foregroundStyle(EquitasTheme.gold.opacity(0.9))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ISSUED")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(EquitasTheme.textSecondary)
                        Text("Apr 2026")
                            .font(EquitasTheme.monoFont)
                            .foregroundStyle(EquitasTheme.textPrimary.opacity(0.8))
                    }
                }
            }
            .padding(22)
        }
        .frame(height: 200)
        .shadow(color: EquitasTheme.purple.opacity(0.4), radius: 28, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Wallet address card
struct WalletAddressCard: View {
    let address: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(EquitasTheme.purple.opacity(0.15)).frame(width: 44)
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(EquitasTheme.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallet Address")
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
                Text(address)
                    .font(EquitasTheme.monoFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = address
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15))
                    .foregroundStyle(copied ? EquitasTheme.gold : EquitasTheme.textSecondary)
                    .animation(.spring, value: copied)
            }
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
    }
}

// MARK: - Linked programs
struct LinkedProgramsCard: View {
    private let programs: [(String, String, String)] = [
        ("SNAP Benefits",        "cart.fill",              "Active"),
        ("WIC Program",          "heart.fill",             "Eligible"),
        ("Medicaid",             "cross.case.fill",        "Eligible"),
        ("Housing Assistance",   "house.fill",             "Pending"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Linked Programs")
                .font(EquitasTheme.headlineFont)
                .foregroundStyle(EquitasTheme.textPrimary)
                .padding(.horizontal, 4)

            ForEach(programs, id: \.0) { name, icon, status in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(status == "Active" ? EquitasTheme.gold.opacity(0.12) : EquitasTheme.purple.opacity(0.10))
                            .frame(width: 40)
                        Image(systemName: icon)
                            .font(.system(size: 15))
                            .foregroundStyle(status == "Active" ? EquitasTheme.gold : EquitasTheme.purple)
                    }
                    Text(name)
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    Spacer()
                    Text(status)
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(statusColor(status))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor(status).opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(statusColor(status).opacity(0.3), lineWidth: 1))
                }
                .padding(14)
                .glassCard()
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Active": return EquitasTheme.gold
        case "Eligible": return EquitasTheme.purple
        default: return EquitasTheme.textSecondary
        }
    }
}
