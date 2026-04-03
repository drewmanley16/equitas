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
                    guard url.scheme == "equitas" else { return }
                    switch url.host {
                    case "worldid-callback":
                        // Legacy return_to callback (kept for compatibility)
                        appState.pendingWorldIDCallback = url
                    case "worldid-oidc-callback":
                        // OIDC authorization code callback from World ID hosted page
                        appState.pendingOIDCCallback = url
                    default:
                        break
                    }
                }
        }
    }
}
