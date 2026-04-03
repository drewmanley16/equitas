import SwiftUI

@main
struct equitasApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}
