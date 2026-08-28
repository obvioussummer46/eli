import SwiftUI

/// Opens a portal file (worksheet, PDF, image) inside the app.
///
/// It has to be in-app: attachments sit behind the session, and Safari has its
/// own cookie jar, so an external link would land on the login page.
struct DocumentSheet: View {
    let attachment: Attachment

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = WebViewStore(injectsMobileStyle: false)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebViewRepresentable(store: store)
                    .ignoresSafeArea(edges: .bottom)
                if store.isLoading {
                    ProgressView().progressViewStyle(.linear)
                }
                if let message = store.lastErrorMessage {
                    InlineErrorBanner(message: message) { store.reload() }
                        .padding(12)
                }
            }
            .navigationTitle(attachment.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: attachment.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await SPHCookies.exportToWebView()
            store.load(attachment.url)
        }
    }
}
