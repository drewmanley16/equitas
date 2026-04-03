import SwiftUI

struct EligibilityCompleteView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
            VStack(spacing: 8) {
                Text("You're Eligible!")
                    .font(.largeTitle.bold())
                Text("Your SNAP benefits are ready. Your eligibility NFT has been minted on Hedera.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PrimaryButton(title: "Go to Wallet") {
                appState.eligibilityStatus = .complete
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding(32)
    }
}
