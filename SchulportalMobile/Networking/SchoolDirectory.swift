import Foundation

/// The portal's public school directory — the list behind the login page's own
/// school picker.
///
/// It is deliberately *not* an `SPHClient` call. This runs before anybody is
/// signed in, against a cache host that wants no cookies, and `SPHClient` would
/// answer a redirect to the login host with `.notLoggedIn` — which is precisely
/// the state the caller is trying to get out of. So it gets its own ephemeral
/// session and never touches `HTTPCookieStorage.shared`.
///
/// The payload is one array of *Schulämter*, each with its schools:
///
/// ```json
/// [{"Id":"7","Name":"Bergstraße/Odenwaldkreis",
///   "Schulen":[{"Id":"3354","Name":"Adam-Karrillon-Schule","Ort":"Wald-Michelbach"}]}]
/// ```
///
/// Ids arrive as strings here but as numbers elsewhere in the portal, so they
/// are read for their meaning rather than their declared type — without
/// borrowing `MensaJSON`, which belongs to the other, unrelated stack.
actor SchoolDirectory {
    static let shared = SchoolDirectory()

    private var cached: [School]?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": SPHClient.userAgent,
            "Accept": "application/json,text/plain,*/*",
            "Accept-Language": "de-DE,de;q=0.9"
        ]
        session = URLSession(configuration: config)
    }

    /// The whole directory, sorted by name. Fetched once per app run — it is
    /// ~140 KB and changes about once a school year, and a school is picked
    /// once and then never again.
    func all() async throws -> [School] {
        if let cached { return cached }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: SPHEndpoints.schoolList)
        } catch let error as URLError {
            throw SPHError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SPHError.badResponse(http.statusCode)
        }

        let schools = Self.parse(data)
        guard !schools.isEmpty else { throw SPHError.parsing("Die Schulliste") }
        cached = schools
        return schools
    }

    // MARK: - Parsing

    static func parse(_ data: Data) -> [School] {
        guard let districts = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }

        var schools: [School] = []
        for case let district as [String: Any] in districts {
            let districtName = Self.text(district["Name"]) ?? ""
            guard let entries = district["Schulen"] as? [Any] else { continue }
            for case let entry as [String: Any] in entries {
                guard let id = Self.text(entry["Id"]),
                      let name = Self.text(entry["Name"]) else { continue }
                schools.append(School(id: id,
                                      name: name,
                                      city: Self.text(entry["Ort"]) ?? "",
                                      district: districtName))
            }
        }
        // Same name in two towns is common, so the town is the tie-breaker.
        return schools.sorted {
            $0.name == $1.name ? $0.city < $1.city : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// A `String` or a number, as a non-empty `String`.
    private static func text(_ value: Any?) -> String? {
        let string: String?
        switch value {
        case let text as String: string = text
        case let number as NSNumber: string = number.stringValue
        default: string = nil
        }
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Every school matching `query`, best matches first.
    ///
    /// All the terms must appear, in any order and any field, so
    /// „gymnasium bensheim“ works as well as „bensheim gymnasium“. A name that
    /// *starts* with the query wins over one that merely contains it.
    static func search(_ query: String, in schools: [School]) -> [School] {
        let terms = query.folded.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return schools }

        let matches = schools.filter { school in
            let haystack = school.searchText
            return terms.allSatisfy(haystack.contains)
        }
        let prefix = terms.joined(separator: " ")
        return matches.sorted { lhs, rhs in
            let l = lhs.name.folded.hasPrefix(prefix)
            let r = rhs.name.folded.hasPrefix(prefix)
            if l != r { return l }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
