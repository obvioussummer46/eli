import SwiftUI

@main
struct SchulportalMobileApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .animation(.easeInOut(duration: 0.2), value: model.phase)
                .task { await model.bootstrap() }
                .onChange(of: scenePhase) { previous, phase in
                    guard previous == .background, phase == .active,
                          model.phase == .ready, model.settings.refreshesOnLaunch else { return }
                    Task { await model.refresh() }
                }
        }
    }
}
