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
/// keyed by Schulnummer in `Resources/schools.json`. Adding a school is a
/// one-entry PR, not a fork.
enum SchoolRegistry {
    /// `static let` initialisation is thread-safe, and `MensaClient` reads
    /// the tenant off the main actor.
    private static let entries: [String: SchoolConfig] = {
        guard let url = Bundle.main.url(forResource: "schools", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: SchoolConfig].self, from: data)
        else { return [:] }
        return decoded
    }()

    static func entry(for schoolID: String) -> SchoolConfig? {
        entries[schoolID]
    }
}
