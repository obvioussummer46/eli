import SafariServices
import SwiftUI

/// External school pages („Meine Schule" links) open in `SFSafariViewController`
/// rather than the app's own web view: these sites are not the portal, get no
/// mobile restyle injected, and Safari's reader/share/cookie handling is
/// exactly what a plain website visit wants.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
