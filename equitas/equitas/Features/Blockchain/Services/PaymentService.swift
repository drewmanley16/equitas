import Foundation

actor PaymentService {
    struct SetupMerchantBody: Codable {
        let merchantAddress: String
        let approved: Bool
    }

    struct SetupMerchantResponse: Codable {
        let ok: Bool?
        let txHash: String?
        let txExplorerURL: String?
    }

    struct PayMerchantBody: Codable {
        let merchantAddress: String
        let amountAtomic: String
    }

    struct PayMerchantResponse: Codable {
        let ok: Bool?
        let txHash: String?
        let txExplorerURL: String?
    }

    /// Demo path: backend signs with `BENEFICIARY_PRIVATE_KEY`. Production should sign `payMerchant` on-device.
    func payMerchant(merchantAddress: String, amountAtomic: String) async throws -> PayMerchantResponse {
        try await APIClient.shared.post(
            endpoint: .benefitsPayMerchant,
            body: PayMerchantBody(merchantAddress: merchantAddress, amountAtomic: amountAtomic)
        )
    }

    func approveMerchant(merchantAddress: String) async throws -> SetupMerchantResponse {
        try await APIClient.shared.post(
            endpoint: .benefitsSetupMerchant,
            body: SetupMerchantBody(merchantAddress: merchantAddress, approved: true)
        )
    }
}
