import Foundation

struct BenefitsStatusResponse: Codable {
    let userAddress: String
    let eligible: Bool
    let allowanceAtomic: String
    let spentAtomic: String
    let remainingAtomic: String
    let expiryTimestamp: String
    let paused: Bool
}

struct ApprovedMerchant: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
}

@Observable
@MainActor
final class WalletViewModel {
    var remainingDisplay: String = "—"
    var eligible: Bool = false
    var paused: Bool = false
    var selectedMerchantID: String
    var payAmountDollars: String = "5.00"
    var statusMessage: String?
    var isBusy: Bool = false
    var activities: [WalletActivity] = []
    let approvedMerchants: [ApprovedMerchant]

    private let keychain = KeychainService()
    private let activityStore = WalletActivityStore()
    private let zeroAddress = "0x0000000000000000000000000000000000000000"
    private let localDemoAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

    init() {
        let merchants = [
            ApprovedMerchant(id: "trader-joes", name: "Trader Joe's", address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"),
            ApprovedMerchant(id: "safeway", name: "Safeway", address: "0x90F79bf6EB2c4f870365E785982E1f101E93b906"),
            ApprovedMerchant(id: "walmart", name: "Walmart", address: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"),
            ApprovedMerchant(id: "five-guys", name: "Five Guys", address: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc")
        ]
        approvedMerchants = merchants
        selectedMerchantID = merchants.first?.id ?? ""
    }

    func refreshStatus() async {
        guard let addr = normalizedWalletAddress() else {
            statusMessage = "No wallet on device"
            return
        }
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        do {
            let s: BenefitsStatusResponse = try await APIClient.shared.get(endpoint: .benefitsStatus(addr))
            eligible = s.eligible
            paused = s.paused
            remainingDisplay = Self.formatUSDC6(s.remainingAtomic)
            activities = activityStore.load()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func payMerchant() async {
        guard let atomic = Self.dollarsToAtomic6(payAmountDollars) else {
            statusMessage = "Invalid amount"
            return
        }
        guard let merchant = selectedMerchant else {
            statusMessage = "Select an approved merchant"
            return
        }
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        let pendingId = activityStore.recordPendingPurchase(
            amountAtomic: atomic,
            merchantName: merchant.name,
            merchantAddress: merchant.address
        )
        activities = activityStore.load()
        do {
            let payment = try await PaymentService().payMerchant(merchantAddress: merchant.address, amountAtomic: atomic)
            let tx = payment.txHash ?? ""
            if !tx.isEmpty {
                activityStore.completePendingPurchase(
                    id: pendingId,
                    txHash: tx,
                    txExplorerURL: payment.txExplorerURL,
                    merchantName: merchant.name,
                    merchantAddress: merchant.address
                )
            } else {
                activityStore.failPendingPurchase(id: pendingId, merchantName: merchant.name, merchantAddress: merchant.address)
            }
            activities = activityStore.load()
            statusMessage = tx.isEmpty ? "Paid" : "Tx: \(tx)"
            await refreshStatus()
        } catch {
            activityStore.failPendingPurchase(id: pendingId, merchantName: merchant.name, merchantAddress: merchant.address)
            activities = activityStore.load()
            statusMessage = error.localizedDescription
        }
    }

    func createMockPayment() async {
        guard let atomic = Self.dollarsToAtomic6(payAmountDollars) else {
            statusMessage = "Invalid amount"
            return
        }
        guard let merchant = selectedMerchant else {
            statusMessage = "Select an approved merchant"
            return
        }

        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        let pendingId = activityStore.recordPendingPurchase(
            amountAtomic: atomic,
            merchantName: merchant.name,
            merchantAddress: merchant.address
        )
        activities = activityStore.load()

        do {
            let paymentService = PaymentService()
            _ = try await paymentService.approveMerchant(merchantAddress: merchant.address)
            let payment = try await paymentService.payMerchant(merchantAddress: merchant.address, amountAtomic: atomic)
            let tx = payment.txHash ?? ""
            if !tx.isEmpty {
                activityStore.completePendingPurchase(
                    id: pendingId,
                    txHash: tx,
                    txExplorerURL: payment.txExplorerURL,
                    merchantName: merchant.name,
                    merchantAddress: merchant.address
                )
            } else {
                activityStore.failPendingPurchase(id: pendingId, merchantName: merchant.name, merchantAddress: merchant.address)
            }
            activities = activityStore.load()
            statusMessage = tx.isEmpty ? "Mock payment created" : "Tx: \(tx)"
            await refreshStatus()
        } catch {
            activityStore.failPendingPurchase(id: pendingId, merchantName: merchant.name, merchantAddress: merchant.address)
            activities = activityStore.load()
            statusMessage = error.localizedDescription
        }
    }

    private static func formatUSDC6(_ atomic: String) -> String {
        guard let atoms = Decimal(string: atomic) else { return atomic }
        let million = Decimal(1_000_000)
        var dollars = atoms / million
        var rounded = Decimal()
        NSDecimalRound(&rounded, &dollars, 2, .plain)
        return "\(rounded)"
    }

    private static func dollarsToAtomic6(_ s: String) -> String? {
        let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        guard let d = Decimal(string: cleaned) else { return nil }
        let million = Decimal(1_000_000)
        var atoms = d * million
        var rounded = Decimal()
        NSDecimalRound(&rounded, &atoms, 0, .plain)
        return "\(rounded)"
    }

    private func normalizedWalletAddress() -> String? {
        guard let stored = keychain.load(forKey: "walletAddress") else { return nil }
        if stored.caseInsensitiveCompare(zeroAddress) == .orderedSame {
            try? keychain.save(localDemoAddress, forKey: "walletAddress")
            return localDemoAddress
        }
        return stored
    }

    static func shortenHash(_ value: String) -> String {
        guard value.count > 14 else { return value }
        return "\(value.prefix(8))...\(value.suffix(6))"
    }

    var selectedMerchant: ApprovedMerchant? {
        approvedMerchants.first(where: { $0.id == selectedMerchantID })
    }
}
