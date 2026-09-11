import SwiftUI
import WebKit

/// The site's account page in a sheet, signed in with the app's own session —
/// topping up is the one mensa action the app hands to the website. What
/// "aufladen" means (bank-transfer details or an online payment) is the
/// caterer's choice, so the page is shown as-is rather than parsed.
///
/// Paying for food is a physical service, which is why this may be a web page
/// at all (guideline 3.1.5(a)) — no StoreKit anywhere near it.
struct MensaTopUpSheet: View {
    @Environment(MensaModel.self) private var mensa
    @Environment(\.dismiss) private var dismiss

    @State private var store: WebViewStore?

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    TopUpWebView(store: store)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Guthaben aufladen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store?.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store == nil)
                }
            }
        }
        .task { await prepare() }
        .onDisappear {
            // Whatever happened over there, the balance on our side is stale.
            Task { await mensa.refresh() }
        }
    }

    /// Seeds a throwaway cookie store with the client's session before the
    /// first load, so the page opens signed in. With no session to hand over,
    /// the site shows its login page — the user can still get in by hand.
    private func prepare() async {
        guard store == nil else { return }
        let cookies = await mensa.topUpCookies()
        let dataStore = WKWebsiteDataStore.nonPersistent()
        for cookie in cookies {
            await dataStore.httpCookieStore.setCookie(cookie)
        }
        let webStore = WebViewStore(injectsMobileStyle: false, dataStore: dataStore)
        webStore.load(MensaEndpoints.accountPage)
        store = webStore
    }
}

/// Split off so the sheet can hold the store as an optional while this level
/// observes its published loading state.
private struct TopUpWebView: View {
    @ObservedObject var store: WebViewStore

    var body: some View {
        ZStack(alignment: .top) {
            WebViewRepresentable(store: store)
                .ignoresSafeArea(edges: .bottom)
            if store.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
    }
}
