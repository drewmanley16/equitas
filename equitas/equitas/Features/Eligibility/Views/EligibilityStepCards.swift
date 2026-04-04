import SwiftUI

struct MinimalLoadingCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(EquitasTheme.gold)
                .scaleEffect(1.2)
            Text(title)
                .font(EquitasTheme.bodyFont)
                .foregroundStyle(EquitasTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}

struct MinimalSuccessCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(EquitasTheme.gold)
            Text(title)
                .font(EquitasTheme.headlineFont)
                .foregroundStyle(EquitasTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}

struct MinimalFailureCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text(message)
                .font(EquitasTheme.bodyFont)
                .foregroundStyle(EquitasTheme.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Try Again", style: .ghost, action: retry)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}
