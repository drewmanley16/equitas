import SwiftUI

struct ProcessingStepView: View {
    let viewModel: EligibilityViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Finish Verification")
                .font(EquitasTheme.titleFont)
                .foregroundStyle(EquitasTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                ProcessingRow(label: "Create wallet", status: viewModel.walletStatus)
                ProcessingRow(label: "Register ARC wallet", status: viewModel.circlesStatus)
                ProcessingRow(label: "Mint Hedera NFT", status: viewModel.nftStatus)
                ProcessingRow(label: "Fund USDC benefits", status: viewModel.benefitsFundingStatus)
            }
            .padding(EquitasTheme.cardPadding)
            .glassCard()
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
        .task { await viewModel.runBlockchainOrchestration() }
    }
}

struct ProcessingRow: View {
    let label: String
    let status: ProcessingStatus

    var body: some View {
        HStack(spacing: 14) {
            indicator

            Text(label)
                .font(EquitasTheme.bodyFont)
                .foregroundStyle(EquitasTheme.textPrimary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var indicator: some View {
        switch status {
        case .pending:
            Circle()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                .frame(width: 20, height: 20)
        case .inProgress:
            ProgressView()
                .tint(EquitasTheme.gold)
                .frame(width: 20, height: 20)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(EquitasTheme.gold)
                .font(.system(size: 20, weight: .semibold))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 20, weight: .semibold))
        }
    }
}
