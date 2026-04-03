import LocalAuthentication

actor BiometricService {
    func authenticate() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? LAError(.biometryNotAvailable)
        }
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your Equitas wallet"
            ) { success, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: success) }
            }
        }
    }
}
