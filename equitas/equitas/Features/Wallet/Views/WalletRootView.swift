import SwiftUI

struct WalletRootView: View {
    @Bindable var viewModel: WalletViewModel

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    BalanceCard(remaining: viewModel.remainingDisplay)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pay approved merchant")
                            .font(EquitasTheme.headlineFont)
                            .foregroundStyle(EquitasTheme.textPrimary)

                        TextField("Merchant address (0x…)", text: $viewModel.merchantAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        TextField("Amount (USDC)", text: $viewModel.payAmountDollars)
                            .keyboardType(.decimalPad)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        PrimaryButton(title: "Pay merchant", icon: "cart.fill") {
                            Task { await viewModel.payMerchant() }
                        }
                        .disabled(viewModel.isBusy)

                        if let msg = viewModel.statusMessage {
                            Text(msg)
                                .font(EquitasTheme.captionFont)
                                .foregroundStyle(EquitasTheme.textSecondary)
                        }

                        HStack {
                            Text("Allowance \(viewModel.allowanceDisplay)")
                            Spacer()
                            Text("Spent \(viewModel.spentDisplay)")
                        }
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        ActionButton(icon: "apple.logo", label: "Add to Wallet") {}
                        ActionButton(icon: "arrow.up.right", label: "Send") {}
                        ActionButton(icon: "qrcode", label: "Receive") {}
                    }

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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refreshStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(EquitasTheme.gold)
                }
                .disabled(viewModel.isBusy)
            }
        }
        .task { await viewModel.refreshStatus() }
    }

    private var mockTransactions: [Transaction] {[
        Transaction(id: UUID(), label: "Grocery Store", amount: -42.80, date: "Today", icon: "cart.fill"),
        Transaction(id: UUID(), label: "Benefits funded", amount: 847.50, date: "Apr 1", icon: "arrow.down.circle.fill"),
        Transaction(id: UUID(), label: "Pharmacy", amount: -18.40, date: "Mar 29", icon: "cross.fill"),
        Transaction(id: UUID(), label: "Farmer's Market", amount: -31.00, date: "Mar 27", icon: "leaf.fill"),
    ]}
}

// MARK: - Balance card
struct BalanceCard: View {
    let remaining: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SNAP benefits remaining")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                        .tracking(1)
                    Text("$\(remaining)")
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
                Label("USDC (restricted)", systemImage: "link")
                    .font(EquitasTheme.captionFont)
                    .foregroundStyle(EquitasTheme.gold.opacity(0.8))
                Spacer()
                Label("ARC programmable USDC", systemImage: "circle.hexagongrid.fill")
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
