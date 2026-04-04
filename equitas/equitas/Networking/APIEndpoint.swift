import Foundation

enum APIEndpoint: Sendable {
    case zkProve
    case mintNFT
    case benefitsApproveUser
    case benefitsDeposit
    case benefitsSetupMerchant
    case benefitsStatus(String)
    case benefitsPayMerchant

    var path: String {
        switch self {
        case .zkProve:
            return "/api/zk/prove"
        case .mintNFT:
            return "/api/hedera/mint-nft"
        case .benefitsApproveUser:
            return "/api/benefits/approve-user"
        case .benefitsDeposit:
            return "/api/benefits/deposit"
        case .benefitsSetupMerchant:
            return "/api/benefits/setup-merchant"
        case .benefitsStatus(let address):
            return "/api/benefits/status/\(address)"
        case .benefitsPayMerchant:
            return "/api/benefits/pay-merchant"
        }
    }
}
