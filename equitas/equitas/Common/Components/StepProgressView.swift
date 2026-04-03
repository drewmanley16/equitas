import SwiftUI

struct StepProgressView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? EquitasTheme.goldGradient : LinearGradient(
                        colors: [Color.white.opacity(0.2)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: i == currentStep ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
    }
}
