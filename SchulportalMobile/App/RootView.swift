import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.phase {
        case .launching:
            LaunchPlaceholder()
        case .signedOut:
            LoginView()
                .transition(.opacity)
        case .ready:
            MainTabView()
                .transition(.opacity)
        }
    }
}

enum AppTab: String {
    case heute, aufgaben, plan, essen, mehr
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab: AppTab = .heute

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Heute", systemImage: "sun.max") }
                .tag(AppTab.heute)

            HomeworkListView()
                .tabItem { Label("Aufgaben", systemImage: "checklist") }
                // Due today/tomorrow or overdue — not everything open, which
                // kept the badge permanently red and therefore meaningless.
                .badge(model.dueSoonCount)
                .tag(AppTab.aufgaben)

            TimetableView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(AppTab.plan)

            // Hidden, not broken: a school without a known caterer gets no
            // permanently dead Essen tab. Configured via registry/override
            // under „Mehr".
            if model.settings.showsMensaTab {
                MensaTabView()
                    .tabItem { Label("Essen", systemImage: "fork.knife") }
                    .tag(AppTab.essen)
            }

            // Five tabs, deliberately: a sixth would push iOS into its
            // automatic "Mehr" overflow screen and bury this one behind it.
            // The portal browser lives inside this tab instead.
            SettingsView()
                .tabItem { Label("Mehr", systemImage: "gearshape") }
                .tag(AppTab.mehr)
        }
        // Widget taps: `schulportalmobile://tab/<name>`, straight from
        // `widgetURL` — see `WidgetLink`.
        .onOpenURL { url in
            guard url.scheme == "schulportalmobile", url.host == "tab",
                  let tab = AppTab(rawValue: url.lastPathComponent) else { return }
            // A hidden tab must not be selectable, or the TabView lands on
            // nothing renderable.
            if tab == .essen, !model.settings.showsMensaTab { return }
            selectedTab = tab
        }
    }
}

/// Reading a good sentence takes about as long as the session check — so the
/// wait gets a quote instead of a logo staring back.
struct LaunchPlaceholder: View {
    @State private var quote = LaunchQuote.random()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(quote.text)
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                Text("— \(quote.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 36)
            Spacer()
            ProgressView()
                .controlSize(.small)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
