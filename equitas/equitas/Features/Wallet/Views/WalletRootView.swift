import SwiftUI

struct WalletRootView: View {
    @Bindable var viewModel: WalletViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    BalanceCard(remaining: viewModel.remainingDisplay)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        MerchantPicker(selectedMerchantID: $viewModel.selectedMerchantID, merchants: viewModel.approvedMerchants)

                        TextField("Purchase amount", text: $viewModel.payAmountDollars)
                            .keyboardType(.decimalPad)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        PrimaryButton(title: "Pay approved merchant", icon: "cart.fill") {
                            Task { await viewModel.payMerchant() }
                        }
                        .disabled(viewModel.isBusy)

                        PrimaryButton(title: "Create mock payment", icon: "creditcard.fill", style: .ghost) {
                            Task { await viewModel.createMockPayment() }
                        }
                        .disabled(viewModel.isBusy)

                        if let msg = viewModel.statusMessage {
                            Text(msg)
                                .font(EquitasTheme.captionFont)
                                .foregroundStyle(EquitasTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    if !viewModel.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("On-Chain Activity")
                                .font(EquitasTheme.headlineFont)
                                .foregroundStyle(EquitasTheme.textPrimary)
                                .padding(.horizontal, 4)

                            ForEach(viewModel.activities) { tx in
                                TransactionRow(activity: tx, openURL: openURL)
                            }
                        }
                        .padding(.top, 4)
                    }
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
}

// MARK: - Balance card
struct BalanceCard: View {
    let remaining: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wallet balance")
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
        }
        .padding(EquitasTheme.cardPadding)
        .glassCard()
        .shadow(color: EquitasTheme.purple.opacity(0.25), radius: 24, y: 8)
    }
}

// MARK: - Transaction row
struct TransactionRow: View {
    let activity: WalletActivity
    let openURL: OpenURLAction

    var body: some View {
        Button {
            guard let urlString = activity.txExplorerURL,
                  let url = URL(string: urlString) else { return }
            openURL(url)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(amount > 0
                              ? EquitasTheme.gold.opacity(0.12)
                              : EquitasTheme.purple.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 17))
                        .foregroundStyle(amount > 0 ? EquitasTheme.gold : EquitasTheme.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                    Text("Wallet \(WalletViewModel.shortenHash(activity.subtitle))")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                    HStack(spacing: 6) {
                        Text(statusLabel)
                            .font(EquitasTheme.monoFont)
                            .foregroundStyle(statusColor)
                        if activity.txExplorerURL != nil {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(EquitasTheme.gold)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(amount > 0 ? "+$\(amount, specifier: "%.2f")" : "-$\(abs(amount), specifier: "%.2f")")
                        .font(EquitasTheme.headlineFont)
                        .foregroundStyle(amount > 0 ? EquitasTheme.gold : EquitasTheme.textPrimary)
                    Text(secondaryLabel)
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(activity.txExplorerURL == nil)
        .padding(16)
        .glassCard()
    }

    private var amount: Double {
        guard let decimal = Decimal(string: activity.amountAtomic) else { return 0 }
        return NSDecimalNumber(decimal: decimal / Decimal(1_000_000)).doubleValue * sign
    }

    private var statusLabel: String {
        switch activity.status {
        case .pending:
            return "Pending..."
        case .failed:
            return "Failed"
        case .completed:
            if activity.txHash.isEmpty {
                return "Completed"
            }
            return WalletViewModel.shortenHash(activity.txHash)
        }
    }

    private var secondaryLabel: String {
        switch activity.status {
        case .pending:
            return "Submitting"
        case .failed:
            return "Failed"
        case .completed:
            return activity.createdAt.formatted(date: .abbreviated, time: .shortened)
        }
    }

    private var statusColor: Color {
        switch activity.status {
        case .pending:
            return EquitasTheme.gold
        case .failed:
            return Color.red.opacity(0.9)
        case .completed:
            return EquitasTheme.textSecondary
        }
    }

    private var sign: Double {
        activity.kind == .funding ? 1 : -1
    }

    private var iconName: String {
        switch activity.kind {
        case .funding:
            return "arrow.down.circle.fill"
        case .purchase:
            return "creditcard.fill"
        }
    }
}

struct MerchantPicker: View {
    @Binding var selectedMerchantID: String
    let merchants: [ApprovedMerchant]

    var body: some View {
        Menu {
            ForEach(merchants) { merchant in
                Button {
                    selectedMerchantID = merchant.id
                } label: {
                    Label(merchant.name, systemImage: merchant.id == selectedMerchantID ? "checkmark" : "storefront")
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Approved merchant")
                        .font(EquitasTheme.captionFont)
                        .foregroundStyle(EquitasTheme.textSecondary)
                    Text(selectedMerchant?.name ?? "Select merchant")
                        .font(EquitasTheme.bodyFont)
                        .foregroundStyle(EquitasTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(EquitasTheme.gold)
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var selectedMerchant: ApprovedMerchant? {
        merchants.first(where: { $0.id == selectedMerchantID })
    }
}
