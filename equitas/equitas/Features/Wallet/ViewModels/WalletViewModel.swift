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

@Observable
@MainActor
final class WalletViewModel {
    var remainingDisplay: String = "—"
    var allowanceDisplay: String = "—"
    var spentDisplay: String = "—"
    var eligible: Bool = false
    var paused: Bool = false
    var merchantAddress: String = ""
    var payAmountDollars: String = "5.00"
    var statusMessage: String?
    var isBusy: Bool = false

    private let keychain = KeychainService()

    func refreshStatus() async {
        guard let addr = keychain.load(forKey: "walletAddress") else {
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
            allowanceDisplay = Self.formatUSDC6(s.allowanceAtomic)
            spentDisplay = Self.formatUSDC6(s.spentAtomic)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func payMerchant() async {
        guard let atomic = Self.dollarsToAtomic6(payAmountDollars) else {
            statusMessage = "Invalid amount"
            return
        }
        let trimmed = merchantAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("0x"), trimmed.count >= 42 else {
            statusMessage = "Enter merchant 0x address"
            return
        }
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        do {
            let tx = try await PaymentService().payMerchant(merchantAddress: trimmed, amountAtomic: atomic)
            statusMessage = tx.isEmpty ? "Paid" : "Tx: \(tx)"
            await refreshStatus()
        } catch {
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
}
