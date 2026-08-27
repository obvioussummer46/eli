import SwiftUI
import WebKit

/// Hosts the portal's real login page and reports back the moment the session
/// is established.
struct LoginWebSheet: View {
    let schoolID: String
    let onSignedIn: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = WebViewStore(injectsMobileStyle: true)
    @State private var didFinish = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebViewRepresentable(store: store)
                    .ignoresSafeArea(edges: .bottom)
                if store.isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }
            .navigationTitle("Anmelden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            store.onNavigationFinished = { url in
                Task { await checkForSession(url) }
            }
            store.load(SPHEndpoints.login(schoolID: schoolID.isEmpty ? nil : schoolID))
        }
    }

    /// The portal drops us on `start.schulportal.hessen.de` with a `sid` cookie
    /// once the credentials (and any second factor) went through.
    @MainActor
    private func checkForSession(_ url: URL?) async {
        guard !didFinish, let host = url?.host, host == SPHEndpoints.startHost else { return }
        await SPHCookies.importFromWebView()
        guard await SPHClient.shared.hasSessionCookie else { return }
        didFinish = true
        onSignedIn()
    }
}
