import Foundation

enum APIEndpoint {
    case verifyApple
    case worldIDContext
    case worldIDStatus
    case worldIDVerify
    case zkProve
    case mintNFT
    case issueTokens
    case generatePass

    private static let baseURL = "https://api.equitas.app"  // replace with actual backend URL

    var url: URL {
        let path: String
        switch self {
        case .verifyApple:    path = "/api/auth/verify-apple"
        case .worldIDContext: path = "/api/worldid/context"
        case .worldIDStatus:  path = "/api/worldid/status"
        case .worldIDVerify:  path = "/api/worldid/verify"
        case .zkProve:        path = "/api/zk/prove"
        case .mintNFT:        path = "/api/blockchain/mint-nft"
        case .issueTokens:    path = "/api/blockchain/issue-tokens"
        case .generatePass:   path = "/api/wallet/generate-pass"
        }
        return URL(string: Self.baseURL + path)!
    }
}
