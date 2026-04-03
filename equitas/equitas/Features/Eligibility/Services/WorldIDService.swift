import CryptoKit
import Foundation

/// Handles the World ID OIDC "proof of personhood" verification flow.
///
/// OIDC flow (works cross-device — simulator + real World App):
///   1. generatePKCE()       → (verifier, challenge) stored on-device
///   2. oidcAuthorizeURL()   → open in SFSafariViewController
///   3. World ID page shows its own QR code
///   4. User scans QR with World App on ANY device
///   5. World ID redirects to equitas://worldid-oidc-callback?code=X&state=NONCE
///   6. App receives URL via onOpenURL → calls exchangeOIDCCode()
///   7. Backend exchanges code for id_token, extracts nullifier_hash
///
/// NOTE: Register equitas://worldid-oidc-callback as a redirect URI in
///       https://developer.worldcoin.org before using in production.
@MainActor final class WorldIDService {

    // MARK: - PKCE

    /// Generates a PKCE (verifier, challenge) pair using CryptoKit SHA-256.
    func generatePKCE() -> (verifier: String, challenge: String) {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier  = Data(bytes).base64URLEncoded()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
        return (verifier, challenge)
    }

    // MARK: - OIDC URL

    /// Returns the World ID hosted verification URL.
    /// Open this in SFSafariViewController — World ID renders its own QR.
    func oidcAuthorizeURL(nonce: String, codeChallenge: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "id.worldcoin.org"
        components.path   = "/authorize"
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: WorldIDConfig.appID),
            URLQueryItem(name: "redirect_uri",          value: "equitas://worldid-oidc-callback"),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: "openid"),
            URLQueryItem(name: "state",                 value: nonce),
            URLQueryItem(name: "nonce",                 value: nonce),
            URLQueryItem(name: "action",                value: WorldIDConfig.action),
            URLQueryItem(name: "code_challenge",        value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url ?? URL(string: "https://id.worldcoin.org")!
    }

    // MARK: - Callback parsing

    /// Extracts code + state from equitas://worldid-oidc-callback?code=X&state=Y
    func parseOIDCCallback(_ url: URL) -> (code: String, state: String)? {
        guard url.scheme == "equitas",
              url.host   == "worldid-oidc-callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        let params = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard let code  = params["code"],
              let state = params["state"] else { return nil }
        return (code, state)
    }

    // MARK: - Backend token exchange

    /// Sends the OIDC auth code + PKCE verifier to the backend.
    /// Backend exchanges for id_token, extracts nullifier_hash.
    func exchangeOIDCCode(code: String, nonce: String, codeVerifier: String) async throws -> WorldIDOIDCExchangeResponse {
        let request = WorldIDOIDCExchangeRequest(code: code, state: nonce, codeVerifier: codeVerifier)
        return try await APIClient.shared.post(
            endpoint: .worldIDOIDCExchange,
            body: request
        )
    }
}
