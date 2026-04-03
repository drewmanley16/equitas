import SwiftUI

struct BiometricLockView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.primary)
            Text("Unlock Equitas")
                .font(.title2.bold())
            Button("Use Face ID") {
                Task { await unlock() }
            }
            .buttonStyle(.borderedProminent)
        }
        .task { await unlock() }
    }

    private func unlock() async {
        let service = BiometricService()
        if (try? await service.authenticate()) == true {
            appState.authState = .unlocked
        }
    }
}
