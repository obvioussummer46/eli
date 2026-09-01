import BackgroundTasks
import Foundation
import OSLog

/// Keeps the app current without anyone opening it — which is what makes the
/// widgets, the 17:00 homework reminder and the evening digest trustworthy.
///
/// iOS decides when (and whether) the task actually runs; the contract here
/// is only: registered before launch finishes, rescheduled after every run,
/// and never running longer than the system allows. The silent SPH re-login
/// already works headless, so a background refresh behaves exactly like a
/// foreground one.
enum BackgroundRefresh {
    static let identifier = "de.schulportalmobile.app.refresh"
    private static let logger = Logger(subsystem: "de.schulportalmobile.app", category: "background")

    private static var isRegistered = false

    /// Must be called from `App.init` — registering after launch is an error,
    /// and registering twice is a crash, hence the guard.
    static func register(appModel: AppModel, mensaModel: MensaModel) {
        guard !isRegistered else { return }
        isRegistered = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            let work = Task { @MainActor in
                logger.notice("Hintergrund-Aktualisierung läuft.")
                if appModel.phase == .ready {
                    await appModel.refresh()
                }
                // The tab toggle also silences the background half, or a
                // switched-off mensa would keep writing balance and dishes
                // back into the widget snapshot.
                if mensaModel.phase == .ready, appModel.settings.showsMensaTab {
                    await mensaModel.refresh()
                }
                // Update-only: ActivityKit refuses to *start* an activity
                // from the background.
                if appModel.phase == .ready {
                    LessonActivityController.sync(model: appModel, canStart: false)
                }
                schedule()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = {
                work.cancel()
                schedule()
                task.setTaskCompleted(success: false)
            }
        }
    }

    /// Ask for a run in ~4 hours. iOS treats it as a floor, not a promise.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simulator builds refuse submission; nothing to do about it.
            logger.notice("Hintergrund-Aktualisierung nicht eingeplant: \(error.localizedDescription, privacy: .public)")
        }
    }
}
