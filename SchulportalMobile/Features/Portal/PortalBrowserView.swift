import SwiftUI

/// Everything the app does not (yet) parse natively — Nachrichten, Kalender,
/// Vertretungsplan, Noten — still lives here, but wearing the same mobile
/// restyle as the Safari userscript.
///
/// No `NavigationStack` of its own: it is pushed from the „Mehr“ tab, whose
/// stack supplies the bar the toolbar items land in.
struct PortalBrowserView: View {
    @Environment(AppModel.self) private var model
    @StateObject private var store = WebViewStore(injectsMobileStyle: true)
    @State private var didLoadInitialPage = false

    private struct Destination: Identifiable, Hashable {
        var id: String { title }
        var title: String
        var icon: String
        var url: URL
    }

    private let destinations: [Destination] = [
        .init(title: "Startseite", icon: "house", url: SPHEndpoints.startseite),
        .init(title: "Nachrichten", icon: "envelope", url: SPHEndpoints.nachrichten),
        .init(title: "Vertretungsplan", icon: "arrow.left.arrow.right", url: SPHEndpoints.vertretungsplan),
        .init(title: "Kalender", icon: "calendar", url: SPHEndpoints.kalender),
        .init(title: "Mein Unterricht", icon: "book", url: SPHEndpoints.meinUnterricht),
        .init(title: "Lerngruppen", icon: "person.3", url: SPHEndpoints.lerngruppen),
        .init(title: "Dateispeicher", icon: "folder", url: SPHEndpoints.dateispeicher),
        .init(title: "Dateiverteilung", icon: "tray.and.arrow.down", url: SPHEndpoints.dateiverteilung),
        .init(title: "Videokonferenz", icon: "video", url: SPHEndpoints.videokonferenz)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            WebViewRepresentable(store: store)
            if store.isLoading {
                ProgressView().progressViewStyle(.linear)
            }
            if let message = store.lastErrorMessage {
                InlineErrorBanner(message: message) { store.reload() }
                    .padding(12)
            }
        }
        .navigationTitle(store.pageTitle.isEmpty ? "Portal" : store.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The system back button already owns the leading edge; the
            // browser's own history goes trailing, next to the page menu.
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { store.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!store.canGoBack)
                Button { store.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!store.canGoForward)
                Menu {
                    ForEach(destinations) { destination in
                        Button {
                            store.load(destination.url)
                        } label: {
                            Label(destination.title, systemImage: destination.icon)
                        }
                    }
                    Divider()
                    Button {
                        store.reload()
                    } label: {
                        Label("Neu laden", systemImage: "arrow.clockwise")
                    }
                    if let url = store.currentURL {
                        Link(destination: url) {
                            Label("In Safari öffnen", systemImage: "safari")
                        }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
            }
        }
        .task {
            guard !didLoadInitialPage else { return }
            didLoadInitialPage = true
            // Hand the session over so the browser tab does not ask for a
            // second login.
            await SPHCookies.exportToWebView()
            store.load(SPHEndpoints.startseite)
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .ready { store.reload() }
        }
    }
}
