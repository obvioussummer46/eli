import Foundation
import UserNotifications

/// The two local notifications the app can usefully send — nothing leaves the
/// device, there is no push, and both are off until switched on under „Mehr“.
enum NotificationScheduler {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // MARK: - Homework

    private static let homeworkPrefix = "homework."

    /// One digest per evening, 17:00, for everything due the next day —
    /// rewritten wholesale on every refresh, so a task ticked off in the
    /// afternoon silently vanishes from its reminder.
    static func rescheduleHomeworkReminders(_ deadlines: [Date: [Homework]]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(homeworkPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            let cal = GermanDate.calendar
            let now = Date()
            for (deadline, items) in deadlines {
                guard !items.isEmpty,
                      let evening = eveningBefore(deadline),
                      evening > now else { continue }

                let content = UNMutableNotificationContent()
                let subjects = Array(Set(items.map(\.subject.name))).sorted()
                content.title = items.count == 1
                    ? "Eine Hausaufgabe für \(GermanDate.relativeLabel(for: deadline, reference: evening))"
                    : "\(items.count) Hausaufgaben für \(GermanDate.relativeLabel(for: deadline, reference: evening))"
                content.body = subjects.joined(separator: ", ")
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: evening),
                    repeats: false)
                let id = homeworkPrefix + ISO8601DateFormatter.dayOnly.string(from: deadline)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    /// 17:00 the evening before — after school, before the bag is packed.
    private static func eveningBefore(_ deadline: Date) -> Date? {
        let cal = GermanDate.calendar
        guard let dayBefore = cal.date(byAdding: .day, value: -1, to: deadline) else { return nil }
        return cal.date(bySettingHour: 17, minute: 0, second: 0, of: dayBefore)
    }

    // MARK: - Mensa

    private static let lowBalanceStampKey = "notify.lowBalance.lastSent"

    /// Immediate, and throttled to one warning every three days — the balance
    /// stays low until someone tops it up, and a daily nag teaches people to
    /// swipe warnings away.
    static func notifyLowBalance(_ balanceDisplay: String) {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lowBalanceStampKey) as? Date,
           Date().timeIntervalSince(last) < 3 * 24 * 3600 {
            return
        }
        defaults.set(Date(), forKey: lowBalanceStampKey)

        let content = UNMutableNotificationContent()
        content.title = "Mensa-Guthaben wird knapp"
        content.body = "Noch \(balanceDisplay) auf der Karte — Zeit zum Aufladen."
        content.sound = .default
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "mensa.lowBalance", content: content, trigger: nil))
    }
}
