import SwiftUI

struct WalletRootView: View {
    @State private var snapBalance: Double = 847.50
    @State private var appeared = false

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Balance card
                    BalanceCard(balance: snapBalance)
                        .padding(.top, 8)

                    // Action row
                    HStack(spacing: 12) {
                        ActionButton(icon: "apple.logo", label: "Add to Wallet") {}
                        ActionButton(icon: "arrow.up.right", label: "Send") {}
                        ActionButton(icon: "qrcode", label: "Receive") {}
                    }

                    // Transactions
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent Activity")
                            .font(EquitasTheme.headlineFont)
                            .foregroundStyle(EquitasTheme.textPrimary)
                            .padding(.horizontal, 4)

                        ForEach(mockTransactions) { tx in
                            TransactionRow(transaction: tx)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, EquitasTheme.screenPadding)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Wallet")
                    .font(EquitasTheme.headlineFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
            }
        }
    }

    private var mockTransactions: [Transaction] {[
        Transaction(id: UUID(), label: "Grocery Store", amount: -42.80, date: "Today", icon: "cart.fill"),
        Transaction(id: UUID(), label: "Benefits Issued", amount: 847.50, date: "Apr 1", icon: "arrow.down.circle.fill"),
        Transaction(id: UUID(), label: "Pharmacy", amount: -18.40, date: "Mar 29", icon: "cross.fill"),
        Transaction(id: UUID(), label: "Farmer's Market", amount: -31.00, date: "Mar 27", icon: "leaf.fill"),
    ]}
}

// MARK: - Balance card
struct BalanceCard: View {
    let balance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SNAP Balance")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                        .tracking(1)
                    Text("$\(balance, specifier: "%.2f")")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(EquitasTheme.textPrimary)
                        .goldGlow(radius: 10)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(EquitasTheme.gold.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Text("$")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(EquitasTheme.goldGradient)
                }
            }

            Divider().background(EquitasTheme.glassStroke)

            HStack {
                Label("Pegged to USDC", systemImage: "link")
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.gold.opacity(0.8))
                Spacer()
                Label("ARC Network", systemImage: "circle.hexagongrid.fill")
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
            }
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
        .shadow(color: EquitasTheme.purple.opacity(0.25), radius: 24, y: 8)
    }
}

// MARK: - Action button
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(EquitasTheme.gold.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(EquitasTheme.goldGradient)
                }
                Text(label)
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction row
struct Transaction: Identifiable {
    let id: UUID
    let label: String
    let amount: Double
    let date: String
    let icon: String
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(transaction.amount > 0
                          ? EquitasTheme.gold.opacity(0.12)
                          : EquitasTheme.purple.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(transaction.amount > 0 ? EquitasTheme.gold : EquitasTheme.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.label)
                    .font(EquitasTheme.bodyFont)
                    .foregroundStyle(EquitasTheme.textPrimary)
                Text(transaction.date)
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.textSecondary)
            }

            Spacer()

            Text(transaction.amount > 0 ? "+$\(transaction.amount, specifier: "%.2f")" : "-$\(abs(transaction.amount), specifier: "%.2f")")
                .font(EquitasTheme.headlineFont)
                .foregroundStyle(transaction.amount > 0 ? EquitasTheme.gold : EquitasTheme.textPrimary)
        }
        .padding(16)
        .glassCard()
    }
}
