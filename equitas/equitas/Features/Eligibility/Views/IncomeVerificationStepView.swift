import SwiftUI

struct IncomeVerificationStepView: View {
    let viewModel: EligibilityViewModel
    @State private var selectedMethod = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            VStack(spacing: 8) {
                Text("Verify Income")
                    .font(.title2.bold())
                Text("Your income is verified with a zero-knowledge proof. Raw data never leaves your device.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Picker("Method", selection: $selectedMethod) {
                Text("Scan Paystub").tag(0)
                Text("Connect Bank").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedMethod == 0 {
                PrimaryButton(title: "Scan Paystub") {
                    Task { await viewModel.startDocumentScan() }
                }
            } else {
                PrimaryButton(title: "Connect Bank Account") {
                    Task { await viewModel.startBankLink() }
                }
            }

            if viewModel.isProvingIncome {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Generating proof…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(32)
    }
}
