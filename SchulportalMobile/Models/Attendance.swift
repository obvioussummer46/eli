import Foundation

/// One column of the portal's attendance table for one course, e.g.
/// `fehlend: 3`. The categories are the table's own header labels, kept as
/// data rather than an enum: schools configure their own set (fehlend,
/// entschuldigt, unentschuldigt, Distanzunterricht, …), and an unknown
/// column must survive the round trip instead of being dropped.
struct AttendanceCount: Codable, Hashable, Identifiable {
    var category: String
    /// As printed by the portal; an empty cell is normalised to "0".
    var value: String

    var id: String { category }
    var number: Int? { Int(value) }
    /// `hasPrefix`, not `contains`: "unentschuldigt" contains "entschuldigt"
    /// and the two must not match each other.
    var isUnexcused: Bool { category.lowercased().hasPrefix("unentschuldigt") }
}

/// The attendance row of one course from the „Anwesenheiten" table on
/// *Mein Unterricht* — counts only; the per-date detail lives on the
/// per-course `sus_view` pages the app deliberately does not fetch.
struct CourseAttendance: Codable, Hashable, Identifiable {
    var courseID: String
    var courseTitle: String
    /// In the table's own column order.
    var counts: [AttendanceCount]

    var id: String { courseID }

    /// Non-numeric cells count as worth showing: the portal only writes
    /// something other than a number when a human put an annotation there.
    var hasAbsences: Bool {
        counts.contains { ($0.number ?? 1) > 0 }
    }
}
