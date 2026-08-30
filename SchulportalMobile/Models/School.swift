import Foundation

/// One school from the portal's public directory.
///
/// The `id` is the number that goes into `login.schulportal.hessen.de/?i=…`,
/// which is the whole reason this list exists: it is the one thing the login
/// page wants and the one thing nobody knows by heart.
///
/// Not `Codable`: only the picked school's id and name are kept, as two plain
/// strings in `Settings`. The directory itself is refetched, never stored.
struct School: Identifiable, Hashable {
    var id: String
    var name: String
    /// The town — the only thing telling the eighteen „Albert-Schweitzer-Schule“
    /// apart, so it is shown on every row.
    var city: String
    /// The *Schulamt* district the directory files it under.
    var district: String
    /// Name + town + district + id, case- and diacritic-folded.
    ///
    /// Stored rather than computed: the directory is some two thousand entries
    /// and folding all of them again on every keystroke is exactly what makes a
    /// search field feel broken.
    let searchText: String

    init(id: String, name: String, city: String, district: String) {
        self.id = id
        self.name = name
        self.city = city
        self.district = district
        self.searchText = "\(name) \(city) \(district) \(id)".folded
    }

    var subtitle: String {
        city.isEmpty ? district : "\(city) · \(district)"
    }
}

extension String {
    /// Case- and diacritic-insensitive, so „Budingen“ finds „Büdingen“ — the
    /// umlaut is the single most likely thing to be typed the other way.
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
    }
}
