import Combine
import Foundation
import SwiftUI
import WebKit

/// Owns a `WKWebView` and republishes the bits SwiftUI needs.
///
/// Used twice: once for the login flow, once for the in-app portal browser that
/// still carries the mobile restyle for pages the app does not parse natively
/// (Nachrichten, Kalender, Vertretungsplan …).
/// Not marked `@MainActor` on purpose: `WKNavigationDelegate` requirements are
/// nonisolated, and every callback already arrives on the main thread.
final class WebViewStore: NSObject, ObservableObject {
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var pageTitle = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var lastErrorMessage: String?

    let webView: WKWebView

    /// Called after every finished navigation — the login flow uses it to spot
    /// the moment the portal lets us in.
    var onNavigationFinished: ((URL?) -> Void)?

    init(injectsMobileStyle: Bool) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        if injectsMobileStyle, let source = MobileStyleScript.source {
            let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            configuration.userContentController.addUserScript(script)
        }

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = SPHClient.userAgent
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func reload() { webView.reload() }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    private func syncState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        pageTitle = webView.title ?? ""
        currentURL = webView.url
    }
}

extension WebViewStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        lastErrorMessage = nil
        syncState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncState()
        onNavigationFinished?(webView.url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        lastErrorMessage = error.localizedDescription
        syncState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Cancelled navigations are noise (they happen on every redirect chase).
        if (error as NSError).code != NSURLErrorCancelled {
            lastErrorMessage = error.localizedDescription
        }
        syncState()
    }
}

/// SwiftUI wrapper. The web view is owned by the store so that navigation state
/// survives view updates.
struct WebViewRepresentable: UIViewRepresentable {
    let store: WebViewStore

    func makeUIView(context: Context) -> WKWebView { store.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Loads the bundled restyle script — the same one that runs as a Safari
/// userscript, kept in `Resources/portal-mobile.js`.
enum MobileStyleScript {
    static let source: String? = {
        guard let url = Bundle.main.url(forResource: "portal-mobile", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return source
    }()
}
