import SwiftUI

// ContentView retained for Xcode previews.
// The live app entry point is AppRouter (see equitasApp.swift).
struct ContentView: View {
    var body: some View {
        AppRouter()
            .environment(AppState())
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
