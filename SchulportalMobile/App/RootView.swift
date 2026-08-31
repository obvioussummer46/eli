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

struct LaunchPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
