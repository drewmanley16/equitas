import Foundation

/// ARC programmable USDC: eligibility unlocks restricted USDC held in `SNAPSpender` (no separate SNAP ERC-20).
actor SNAPBenefitsService {
    /// Demo defaults: $1,000 spending cap (6 decimals), $100 initial deposit into `SNAPSpender`.
    private let defaultAllowanceAtomic = "1000000000"
    private let defaultDepositAtomic = "100000000"

    func fundBenefitsAfterEligibility(walletAddress: String, nftSerial: Int) async throws {
        _ = nftSerial
        struct ApproveBody: Codable {
            let userAddress: String
            let allowanceAtomic: String
            let expiryTimestamp: String?
        }
        struct ApproveResp: Codable {
            let ok: Bool?
        }
        let _: ApproveResp = try await APIClient.shared.post(
            endpoint: .benefitsApproveUser,
            body: ApproveBody(
                userAddress: walletAddress,
                allowanceAtomic: defaultAllowanceAtomic,
                expiryTimestamp: nil
            )
        )

        struct DepositBody: Codable {
            let amountAtomic: String
        }
        struct DepositResp: Codable {
            let ok: Bool?
        }
        let _: DepositResp = try await APIClient.shared.post(
            endpoint: .benefitsDeposit,
            body: DepositBody(amountAtomic: defaultDepositAtomic)
        )
    }
}
