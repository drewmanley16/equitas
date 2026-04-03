import AuthenticationServices
import Foundation

@MainActor final class AuthService {
    func signIn(with credential: ASAuthorizationAppleIDCredential) throws {
        let keychain = KeychainService()
        try keychain.save(credential.user, forKey: "appleUserID")
        // TODO: send identityToken to backend for verification
    }

    func currentUserID() -> String? {
        KeychainService().load(forKey: "appleUserID")
    }
}
