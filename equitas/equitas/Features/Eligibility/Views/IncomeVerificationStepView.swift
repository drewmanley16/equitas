import SwiftUI
import UniformTypeIdentifiers

struct IncomeVerificationStepView: View {
    let viewModel: EligibilityViewModel
    @State private var showFilePicker = false
    @State private var pickerError: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Verify Income")
                .font(EquitasTheme.titleFont)
                .foregroundStyle(EquitasTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.isProvingIncome {
                MinimalLoadingCard(title: "Verifying income")
            } else {
                VStack(spacing: 16) {
                    PrimaryButton(title: "Authorize income verification", icon: "arrow.up.doc.fill", style: .gold) {
                        showFilePicker = true
                    }

                    PrimaryButton(title: "Sample Paystub + Mint NFT", icon: "seal.fill", style: .ghost) {
                        pickerError = nil
                        Task { await viewModel.useDemoPaystubForOnchainTesting() }
                    }

                    PrimaryButton(title: "Use Demo Paystub", icon: "sparkles.rectangle.stack.fill", style: .ghost) {
                        pickerError = nil
                        viewModel.useDemoPaystub()
                    }
                }

                if let err = pickerError {
                    Text(err)
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pickerError = nil
                Task { await viewModel.uploadDocument(url: url) }
            case .failure(let error):
                pickerError = error.localizedDescription
            }
        }
    }
}
