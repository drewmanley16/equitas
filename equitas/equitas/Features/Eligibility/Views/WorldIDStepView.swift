import SwiftUI

struct WorldIDStepView: View {
    let viewModel: EligibilityViewModel

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            VStack(spacing: 8) {
                Text("Verify Your Identity")
                    .font(.title2.bold())
                Text("Scan with World App to prove you're a unique person. No personal data is stored.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if let url = viewModel.worldIDConnectorURL {
                QRCodeView(content: url.absoluteString)
                    .frame(width: 220, height: 220)
            } else {
                ProgressView("Preparing verification…")
            }
            Spacer()
        }
        .padding(32)
        .task { await viewModel.startWorldIDVerification() }
    }
}
