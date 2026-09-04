import SwiftUI

@main
struct SchulportalMobileApp: App {
    @State private var model = AppModel()
    /// The mensa is its own service with its own account, so it gets its own
    /// model rather than a corner of `AppModel`.
    @State private var mensa = MensaModel()
    /// Purchases and entitlements — one instance, alive for the whole
    /// session so `Transaction.updates` is never missed.
    @State private var store = Store()
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
                .environment(store)
                .animation(.easeInOut(duration: 0.2), value: model.phase)
                .task {
                    store.start()
                    await model.bootstrap()
                    if model.phase == .ready {
                        LessonActivityController.sync(model: model, canStart: true)
                    }
                }
                .onChange(of: scenePhase) { previous, phase in
                    if phase == .background {
                        BackgroundRefresh.schedule()
                        return
                    }
                    if phase == .active, model.phase == .ready {
                        // Widget ticks first, so the list is right before
                        // any refresh — and even when none follows.
                        model.absorbWidgetTicks()
                        LessonActivityController.sync(model: model, canStart: true)
                    }
                    guard previous == .background, phase == .active,
                          model.settings.refreshesOnLaunch else { return }
                    if model.phase == .ready { Task { await model.refresh() } }
                    // The balance is the one number that must never be stale.
                    if mensa.phase == .ready, model.settings.showsMensaTab {
                        Task { await mensa.refresh() }
                    }
                }
        }
    }
}
