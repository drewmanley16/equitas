import Foundation

actor PaymentService {
    struct PayMerchantBody: Codable {
        let merchantAddress: String
        let amountAtomic: String
    }

    struct PayMerchantResponse: Codable {
        let ok: Bool?
        let txHash: String?
    }

    /// Demo path: backend signs with `BENEFICIARY_PRIVATE_KEY`. Production should sign `payMerchant` on-device.
    func payMerchant(merchantAddress: String, amountAtomic: String) async throws -> String {
        let r: PayMerchantResponse = try await APIClient.shared.post(
            endpoint: .benefitsPayMerchant,
            body: PayMerchantBody(merchantAddress: merchantAddress, amountAtomic: amountAtomic)
        )
        return r.txHash ?? ""
    }
}
