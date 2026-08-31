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

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "sun.max") }

            HomeworkListView()
                .tabItem { Label("Aufgaben", systemImage: "checklist") }
                // Due today/tomorrow or overdue — not everything open, which
                // kept the badge permanently red and therefore meaningless.
                .badge(model.dueSoonCount)

            TimetableView()
                .tabItem { Label("Plan", systemImage: "calendar") }

            MensaTabView()
                .tabItem { Label("Essen", systemImage: "fork.knife") }

            // Five tabs, deliberately: a sixth would push iOS into its
            // automatic "Mehr" overflow screen and bury this one behind it.
            // The portal browser lives inside this tab instead.
            SettingsView()
                .tabItem { Label("Mehr", systemImage: "gearshape") }
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
