import SafariServices
import SwiftUI

/// Wraps SFSafariViewController for use in SwiftUI sheets.
/// Used for the World ID OIDC verification flow.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        // Match Equitas dark/gold theme
        vc.preferredBarTintColor     = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
        vc.preferredControlTintColor = UIColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1.0)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
