import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1
    @State private var walletViewModel = WalletViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                EligibilityRootView()
            }
            .tabItem {
                Label("Eligibility", systemImage: "checkmark.seal.fill")
            }
            .tag(0)

            NavigationStack {
                WalletRootView(viewModel: walletViewModel)
            }
            .tabItem {
                Label("Wallet", systemImage: "wallet.bifold.fill")
            }
            .tag(1)

            NavigationStack {
                AccountRootView()
            }
            .tabItem {
                Label("Account", systemImage: "person.crop.circle.fill")
            }
            .tag(2)
        }
        .tint(EquitasTheme.gold)
        // Dark translucent tab bar to match cosmic theme
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
