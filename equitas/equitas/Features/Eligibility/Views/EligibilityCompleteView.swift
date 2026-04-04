import SwiftUI

struct EligibilityCompleteView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(EquitasTheme.gold)
            VStack(spacing: 8) {
                Text("Verification Complete")
                    .font(EquitasTheme.titleFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
                Text("Your eligibility NFT is ready and your benefits flow is unlocked.")
                    .font(EquitasTheme.bodyFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Go to Wallet") {
                appState.eligibilityStatus = .complete
            }
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
    }
}
