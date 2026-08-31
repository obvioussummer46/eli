import SwiftUI

@main
struct SchulportalMobileApp: App {
    @State private var model = AppModel()
    /// The mensa is its own service with its own account, so it gets its own
    /// model rather than a corner of `AppModel`.
    @State private var mensa = MensaModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Background-task handlers must exist before launch finishes.
        BackgroundRefresh.register(appModel: model, mensaModel: mensa)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(mensa)
                .animation(.easeInOut(duration: 0.2), value: model.phase)
                .task { await model.bootstrap() }
                .onChange(of: scenePhase) { previous, phase in
                    if phase == .background {
                        BackgroundRefresh.schedule()
                        return
                    }
                    guard previous == .background, phase == .active,
                          model.settings.refreshesOnLaunch else { return }
                    if model.phase == .ready { Task { await model.refresh() } }
                    // The balance is the one number that must never be stale.
                    if mensa.phase == .ready { Task { await mensa.refresh() } }
                }
        }
    }
}
