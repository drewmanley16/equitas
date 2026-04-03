import SwiftUI

struct EligibilityRootView: View {
    @State private var viewModel = EligibilityViewModel()

    var body: some View {
        NavigationStack {
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
                    ContentUnavailableView(
                        "Verification Failed",
                        systemImage: "xmark.circle",
                        description: Text(error.localizedDescription)
                    )
                }
            }
            .navigationTitle("Eligibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StepProgressView(currentStep: viewModel.stepIndex, totalSteps: 3)
                }
            }
        }
    }
}
