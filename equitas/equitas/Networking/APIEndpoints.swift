import Foundation

enum APIEndpoint: Sendable {
    case verifyApple
    case worldIDContext
    case worldIDStatus
    case worldIDVerify
    case worldIDOIDCExchange
    case zkProve
    case mintNFT
    case issueTokens
    case generatePass
    case benefitsApproveUser
    case benefitsDeposit
    case benefitsSetupMerchant
    case benefitsStatus(String)
    case benefitsPayMerchant

    private static let baseURL: String = {
        #if DEBUG
        return "http://10.105.176.151:3000"   // local backend — Mac LAN IP (works on device + simulator)
        #else
        return "https://api.equitas.app" // Railway production URL — update after deploy
        #endif
    }()

    var url: URL {
        let path: String
        switch self {
        case .verifyApple:          path = "/api/auth/verify-apple"
        case .worldIDContext:       path = "/api/worldid/context"
        case .worldIDStatus:        path = "/api/worldid/status"
        case .worldIDVerify:        path = "/api/worldid/verify"
        case .worldIDOIDCExchange:  path = "/api/worldid/oidc-exchange"
        case .zkProve:              path = "/api/zk/prove"
        case .mintNFT:               path = "/api/blockchain/mint-nft"
        case .issueTokens:           path = "/api/blockchain/issue-tokens"
        case .generatePass:          path = "/api/wallet/generate-pass"
        case .benefitsApproveUser:   path = "/api/benefits/approve-user"
        case .benefitsDeposit:       path = "/api/benefits/deposit"
        case .benefitsSetupMerchant: path = "/api/benefits/setup-merchant"
        case .benefitsStatus(let address): path = "/api/benefits/status/\(address)"
        case .benefitsPayMerchant:   path = "/api/benefits/pay-merchant"
        }
        return URL(string: Self.baseURL + path)!
    }
}
