import SwiftUI
import UniformTypeIdentifiers

struct IncomeVerificationStepView: View {
    let viewModel: EligibilityViewModel
    @State private var showFilePicker = false
    @State private var pickerError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .blur(radius: 20)
                            .frame(width: 120)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 52))
                            .foregroundStyle(EquitasTheme.goldGradient)
                            .goldGlow(radius: 16)
                    }
                    Text("Verify Income")
                        .font(EquitasTheme.titleFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    Text("Your paystub is parsed on our server and a zero-knowledge proof is generated — your raw income is never stored or shared.")
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                if viewModel.isProvingIncome {
                    // Proving state
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(EquitasTheme.gold)
                            .scaleEffect(1.4)
                        Text("Generating zero-knowledge proof…")
                            .font(EquitasTheme.bodyFont)
                            .foregroundStyle(EquitasTheme.textSecondary)
                        Text("Parsing paystub and computing commitment")
                            .font(EquitasTheme.captionFont)
                            .foregroundStyle(EquitasTheme.textSecondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(EquitasTheme.cardPadding)
                    .glassCard()
                } else {
                    // Upload options
                    VStack(spacing: 16) {

                        // Primary: Upload from Files (works)
                        PrimaryButton(title: "Upload Paystub (PDF)", icon: "arrow.up.doc.fill", style: .gold) {
                            showFilePicker = true
                        }

                        PrimaryButton(title: "Use Demo Paystub", icon: "sparkles.rectangle.stack.fill", style: .ghost) {
                            pickerError = nil
                            viewModel.useDemoPaystub()
                        }

                        // Secondary: Scan with camera (placeholder)
                        PrimaryButton(title: "Scan Document", icon: "camera.fill", style: .ghost) {
                            Task { await viewModel.startDocumentScan() }
                        }
                        .overlay(alignment: .topTrailing) {
                            Text("Coming soon")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(EquitasTheme.purple, in: Capsule())
                                .offset(x: -8, y: -8)
                        }
                    }

                    if let err = pickerError {
                        Text(err)
                            .font(EquitasTheme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("Demo mode skips PDF parsing and marks the income step as eligible so you can continue through the rest of the UI.")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)

                    // How it works card
                    HowItWorksCard()
                }
            }
            .padding(.horizontal, EquitasTheme.screenPadding)
            .padding(.bottom, 32)
        }
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

// MARK: - How it works

private struct HowItWorksCard: View {
    private let steps: [(String, String)] = [
        ("1", "Upload your most recent paystub as a PDF"),
        ("2", "We parse your gross income and pay period"),
        ("3", "A ZK proof is generated — only your eligibility is recorded, not the amount"),
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
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Text(number)
                            .font(EquitasTheme.captionFont)
                            .foregroundStyle(.green)
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
