import SwiftUI

struct EligibilityRootView: View {
    @Environment(AppState.self) private var appState

    private var viewModel: EligibilityViewModel {
        appState.eligibilityViewModel
    }

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    EligibilityChecklist(viewModel: viewModel)
                        .padding(.top, 8)

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
                            MinimalFailureCard(message: error.localizedDescription) {
                                viewModel.currentStep = .worldID
                            }
                            .padding(EquitasTheme.cardPadding)
                            .glassCard()
                        }
                    }
                }
                .padding(.horizontal, EquitasTheme.screenPadding)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Authorize")
                    .font(EquitasTheme.headlineFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct EligibilityChecklist: View {
    let viewModel: EligibilityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ChecklistRow(
                title: "World ID",
                subtitle: subtitle(for: .worldID),
                state: state(for: .worldID)
            )
            ChecklistRow(
                title: "Income verification",
                subtitle: subtitle(for: .incomeVerification),
                state: state(for: .incomeVerification)
            )
            ChecklistRow(
                title: "Mint and funding",
                subtitle: subtitle(for: .processing),
                state: state(for: .processing)
            )
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
    }

    private func state(for step: VerificationStep) -> ChecklistState {
        switch step {
        case .worldID:
            return currentIndex > 0 ? .complete : (currentIndex == 0 ? .active : .locked)
        case .incomeVerification:
            return currentIndex > 1 ? .complete : (currentIndex == 1 ? .active : .locked)
        case .processing:
            if case .complete = viewModel.currentStep { return .complete }
            return currentIndex == 2 ? .active : .locked
        default:
            return .locked
        }
    }

    private func subtitle(for step: VerificationStep) -> String {
        switch step {
        case .worldID:
            return currentIndex == 0 ? "Active" : "Approved"
        case .incomeVerification:
            return currentIndex < 1 ? "Hidden until World ID is approved" : (currentIndex == 1 ? "Active" : "Approved")
        case .processing:
            if case .complete = viewModel.currentStep { return "Finished" }
            return currentIndex < 2 ? "Hidden until income verification is approved" : "Active"
        default:
            return ""
        }
    }

    private var currentIndex: Int { viewModel.stepIndex }
}

private enum ChecklistState {
    case locked
    case active
    case complete
}

private struct ChecklistRow: View {
    let title: String
    let subtitle: String
    let state: ChecklistState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 26, height: 26)
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EquitasTheme.headlineFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
                Text(subtitle)
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch state {
        case .locked: return "lock.fill"
        case .active: return "ellipsis"
        case .complete: return "checkmark"
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .locked: return Color.white.opacity(0.07)
        case .active: return EquitasTheme.gold.opacity(0.18)
        case .complete: return EquitasTheme.gold
        }
    }

    private var iconColor: Color {
        switch state {
        case .locked: return EquitasTheme.textSecondary
        case .active: return EquitasTheme.gold
        case .complete: return .black
        }
    }
}
