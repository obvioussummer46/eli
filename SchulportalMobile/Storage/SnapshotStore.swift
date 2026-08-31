import Foundation
import OSLog

/// Everything the app caches locally so it opens instantly and stays useful
/// offline.
struct Snapshot: Codable, Equatable {
    var courses: [Course] = []
    var entries: [LessonEntry] = []
    var timetable = Timetable()
    var lastRefresh: Date?
    /// Homework id -> the state the user set in this app.
    var doneOverrides: [String: DoneOverride] = [:]
    /// Homework the portal has since dropped from "aktuelle Einträge" but that
    /// the user never ticked off — keeping them avoids silently losing an open
    /// task after two weeks.
    var archivedHomework: [Homework] = []
    /// Optional so snapshots written before this field existed still decode.
    /// Stale days age out naturally: the UI only ever asks for dated days.
    var substitutions: SubstitutionPlan?
    /// The school calendar, same deal: optional for old snapshots, and past
    /// events fall out of every view by date.
    var events: [SchoolEvent]?
}

/// A locally set done-flag, remembered even when the portal round-trip failed.
struct DoneOverride: Codable, Equatable, Hashable {
    var isDone: Bool
    var changedAt: Date
    /// `false` while the portal has not confirmed the change yet.
    var syncedToPortal: Bool
}

/// Atomic JSON persistence in Application Support.
actor SnapshotStore {
    static let shared = SnapshotStore()

    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "storage")
    private let fileURL: URL

    init(filename: String = "snapshot.json") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        let folder = base.appendingPathComponent("SchulportalMobile", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent(filename)
    }

    func load() -> Snapshot {
        guard let data = try? Data(contentsOf: fileURL) else { return Snapshot() }
        do {
            return try JSONDecoder.portal.decode(Snapshot.self, from: data)
        } catch {
            // A schema change must never brick the app; start over instead.
            logger.error("Snapshot unlesbar, wird verworfen: \(error.localizedDescription, privacy: .public)")
            return Snapshot()
        }
    }

    func save(_ snapshot: Snapshot) {
        do {
            let data = try JSONEncoder.portal.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Snapshot konnte nicht gesichert werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

extension JSONDecoder {
    static let portal: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let portal: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
