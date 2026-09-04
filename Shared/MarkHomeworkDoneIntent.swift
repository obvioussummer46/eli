import AppIntents
import Foundation
import WidgetKit

/// The tick on the interactive homework widget. Runs inside the widget
/// extension, which has no portal session — so it only records the tick in
/// the App Group; the app absorbs it on its next foreground or refresh and
/// pushes it to the portal through the normal `setDone` path. Same rule as
/// everywhere else: the local flag always wins, and it is never lost.
struct MarkHomeworkDoneIntent: AppIntent {
    static var title: LocalizedStringResource { "Hausaufgabe abhaken" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Hausaufgabe")
    var homeworkID: String

    init() {}

    init(homeworkID: String) {
        self.homeworkID = homeworkID
    }

    func perform() async throws -> some IntentResult {
        SharedHomeworkTicks.record(homeworkID)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.homework)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.dayPlan)
        return .result()
    }
}

/// Ticks made on the widget that the app has not absorbed yet — homework id
/// to the moment of the tap. A tiny JSON next to the snapshot.
enum SharedHomeworkTicks {
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedSnapshotStore.appGroupID)?
            .appendingPathComponent("homework-ticks.json")
    }

    static func load() -> [String: Date] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    static func record(_ id: String) {
        var ticks = load()
        ticks[id] = Date()
        save(ticks)
    }

    static func remove(_ ids: some Sequence<String>) {
        var ticks = load()
        for id in ids { ticks.removeValue(forKey: id) }
        save(ticks)
    }

    private static func save(_ ticks: [String: Date]) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(ticks) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// The `kind` strings the widgets register under — shared so the intent can
/// reload exactly the timelines it changed.
enum WidgetKind {
    static let nextLesson = "NextLesson"
    static let today = "Today"
    static let mensa = "Mensa"
    static let homework = "Homework"
    static let dayPlan = "DayPlan"
    static let countdown = "Countdown"
}
