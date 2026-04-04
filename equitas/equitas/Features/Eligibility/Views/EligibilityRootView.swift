import SwiftUI

struct EligibilityRootView: View {
    @Environment(AppState.self) private var appState

    private var viewModel: EligibilityViewModel {
        appState.eligibilityViewModel
    }

    var body: some View {
        ZStack {
            CosmicBackground()

            Group {
                switch viewModel.currentStep {
                case .worldID:
                    WorldIDStepView(viewModel: viewModel)
                case .incomeVerification:
                    IncomeVerificationStepView(viewModel: viewModel)
                case .processing:
                    ProcessingStepView(viewModel: viewModel)
                case .complete:
                    EligibilityCompleteView()
                case .failed(let error):
                    VStack(spacing: 20) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.red)
                        Text("Verification Failed")
                            .font(EquitasTheme.titleFont)
                            .foregroundStyle(EquitasTheme.textPrimary)
                        Text(error.localizedDescription)
                            .font(EquitasTheme.bodyFont)
                            .foregroundStyle(EquitasTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        PrimaryButton(title: "Try Again", style: .ghost) {
                            viewModel.currentStep = .worldID
                        }
                        .padding(.horizontal, EquitasTheme.screenPadding)
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    Text("Verify")
                        .font(EquitasTheme.headlineFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    StepProgressView(currentStep: viewModel.stepIndex, totalSteps: 3)
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
