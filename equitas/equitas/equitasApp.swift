import SwiftUI

@main
struct equitasApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // World App calls back to equitas://worldid-callback?proof=...
                    if url.scheme == "equitas" && url.host == "worldid-callback" {
                        appState.pendingWorldIDCallback = url
                    }
                }
        }
    }
}
