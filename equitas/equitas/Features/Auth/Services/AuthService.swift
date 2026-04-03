import AuthenticationServices
import Foundation

actor AuthService {
    func signIn(with credential: ASAuthorizationAppleIDCredential) async throws {
        let keychain = KeychainService()
        try keychain.save(credential.user, forKey: "appleUserID")
        // TODO: send identityToken to backend for verification
    }

    func currentUserID() -> String? {
        KeychainService().load(forKey: "appleUserID")
    }
}
