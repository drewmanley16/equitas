import Foundation

/// World ID configuration — swap staging → production values before release.
/// Register your app at https://developer.worldcoin.org
enum WorldIDConfig {
    /// The App ID from the World ID Developer Portal
    static let appID  = "app_6dc3841d23546ffd0ded96c75161a346"

    /// Action identifier — must match what's registered in the portal
    static let action = "equitas01"

    /// Verification level: "orb" (highest trust) or "device"
    static let verificationLevel = "orb"

    /// How often (seconds) to poll the backend while waiting for World App
    static let pollInterval: UInt64 = 2_000_000_000  // 2s in nanoseconds

    /// Maximum number of poll attempts before timing out (~3 minutes)
    static let maxPollAttempts = 90
}
