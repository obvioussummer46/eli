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
                .badge(model.openHomework.count)

            TimetableView()
                .tabItem { Label("Plan", systemImage: "calendar") }

            MensaTabView()
                .tabItem { Label("Essen", systemImage: "fork.knife") }

            PortalBrowserView()
                .tabItem { Label("Portal", systemImage: "safari") }

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
