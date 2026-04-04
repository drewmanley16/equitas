import SwiftUI

struct ProcessingStepView: View {
    let viewModel: EligibilityViewModel

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .symbolEffect(.rotate, isActive: true)
            Text("Setting Up Your Account")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 16) {
                ProcessingRow(label: "Creating wallet", status: viewModel.walletStatus)
                ProcessingRow(label: "Registering on ARC network", status: viewModel.circlesStatus)
                ProcessingRow(label: "Minting eligibility NFT", status: viewModel.nftStatus)
                ProcessingRow(label: "Funding SNAP benefits (USDC)", status: viewModel.benefitsFundingStatus)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .padding(32)
        .task { await viewModel.runBlockchainOrchestration() }
    }
}

struct ProcessingRow: View {
    let label: String
    let status: ProcessingStatus

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            switch status {
            case .pending: Image(systemName: "circle").foregroundStyle(.secondary)
            case .inProgress: ProgressView().scaleEffect(0.8)
            case .complete: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
        }
    }
}
