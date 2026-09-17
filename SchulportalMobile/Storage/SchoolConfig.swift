import Foundation

/// One link on a school's website — either shipped in the registry or added
/// by the user under „Meine Schule".
struct SchoolLink: Codable, Hashable, Identifiable {
    var title: String
    var url: URL

    var id: String { url.absoluteString }
}

/// One school's entry in the bundled registry. Every field is optional:
/// a school the registry does not know simply configures nothing, and the
/// features that would need those values stay invisible — hidden, not broken.
struct SchoolConfig: Codable {
    var name: String?
    /// The school's caterer on `menuebestellung.de` — the path segment the
    /// whole mensa API hangs off. No tenant, no Essen tab.
    var mensaTenant: String?
    var links: [SchoolLink]?
    /// The school's own app icon — an appiconset bundled in the app, listed
    /// in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. Only ever a design
    /// the school agreed to (`Docs/SCHULLOGO-EINWILLIGUNG.md`); unlocked for
    /// free for everyone at that school.
    var iconName: String?
}

/// The per-school registry: everything school-specific is *data, not code*,
/// keyed by Schulnummer. Adding a school is a one-entry PR to
/// `Resources/schools.json`, not a fork — and since the same file is also
/// fetched from the repository at launch, the entry reaches every install
/// on its next start, without an App Store release in between.
///
/// Three layers, later ones winning per school:
/// 1. the copy bundled with the app (always there, never empty),
/// 2. the last remote copy that decoded, cached on disk,
/// 3. the remote copy fetched this run.
///
/// Reads are synchronous and lock-protected: `MensaClient` resolves the
/// tenant off the main actor, and `Settings` reads on it.
enum SchoolRegistry {
    /// The registry as published — the file in the repository's default
    /// branch, so a merged entry is live within a day.
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/obvioussummer46/eli/main/SchulportalMobile/Resources/schools.json")!

    /// A fetch is cheap (a few KB) but not free; once per launch and after a
    /// long time in the background is enough for a file that changes when a
    /// school is added.
    static let minimumRefreshInterval: TimeInterval = 6 * 60 * 60

    private static let lock = NSLock()
    nonisolated(unsafe) private static var entries: [String: SchoolConfig] = loadInitial()
    nonisolated(unsafe) private static var lastRefresh: Date?

    static func entry(for schoolID: String) -> SchoolConfig? {
        lock.lock(); defer { lock.unlock() }
        return entries[schoolID]
    }

    /// Every school the registry currently knows — for tests and diagnostics.
    static var knownSchoolIDs: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return Set(entries.keys)
    }

    // MARK: - Refresh

    /// Fetches the published registry and swaps it in. Returns `true` when
    /// an entry changed, so the caller can tell its views. Never throws:
    /// a failed fetch leaves the cached or bundled copy in place, which is
    /// the whole point of having one.
    @discardableResult
    static func refresh(force: Bool = false) async -> Bool {
        guard force || isDueForRefresh else { return false }
        let session = URLSession(configuration: .ephemeral)
        guard let result = try? await session.data(from: remoteURL),
              let http = result.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let remote = decode(result.0)
        else { return false }
        lock.lock(); lastRefresh = Date(); lock.unlock()
        writeCache(result.0)
        return replace(with: merge(bundled: bundledEntries(), remote: remote))
    }

    private static var isDueForRefresh: Bool {
        lock.lock(); defer { lock.unlock() }
        guard let lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) >= minimumRefreshInterval
    }

    /// For tests: install a registry as if it had just been fetched.
    @discardableResult
    static func replace(with newEntries: [String: SchoolConfig]) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let changed = !isEqual(entries, newEntries)
        entries = newEntries
        return changed
    }

    // MARK: - Layers

    /// A registry file, or `nil` if it is not one. An empty object is not a
    /// registry either: the bundled copy is never empty, so an empty remote
    /// one is a broken deploy, not a decision.
    static func decode(_ data: Data) -> [String: SchoolConfig]? {
        guard let decoded = try? JSONDecoder().decode([String: SchoolConfig].self, from: data),
              !decoded.isEmpty
        else { return nil }
        return decoded
    }

    /// Remote wins per school; a school only the bundle knows stays. So a
    /// remote file that lost an entry cannot take a school's mensa away
    /// until the next app update ships without it too.
    static func merge(bundled: [String: SchoolConfig], remote: [String: SchoolConfig]) -> [String: SchoolConfig] {
        bundled.merging(remote) { _, remote in remote }
    }

    private static func loadInitial() -> [String: SchoolConfig] {
        let bundled = bundledEntries()
        guard let cached = readCache().flatMap(decode) else { return bundled }
        return merge(bundled: bundled, remote: cached)
    }

    private static func bundledEntries() -> [String: SchoolConfig] {
        guard let url = Bundle.main.url(forResource: "schools", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = decode(data)
        else { return [:] }
        return decoded
    }

    // MARK: - Disk cache

    /// Application Support, not Caches: iOS may purge Caches under pressure,
    /// and a school losing its mensa tab because the phone was full would
    /// be a bug nobody could reproduce.
    private static var cacheURL: URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return directory.appendingPathComponent("schools.json")
    }

    private static func readCache() -> Data? {
        guard let cacheURL else { return nil }
        return try? Data(contentsOf: cacheURL)
    }

    private static func writeCache(_ data: Data) {
        guard let cacheURL else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// `SchoolConfig` is not `Equatable` on purpose — it is a decoding
    /// target — so "did anything change" compares the encoded form.
    private static func isEqual(_ lhs: [String: SchoolConfig], _ rhs: [String: SchoolConfig]) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return lhs.allSatisfy { id, config in
            guard let other = rhs[id],
                  let a = try? encoder.encode(config), let b = try? encoder.encode(other) else { return false }
            return a == b
        }
    }
}
