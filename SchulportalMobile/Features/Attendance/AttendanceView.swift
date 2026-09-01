import SwiftUI

/// Fehlzeiten, read from the „Anwesenheiten" table the portal prints on
/// *Mein Unterricht* — so this costs no extra request and shows exactly the
/// counts the portal itself vouches for. The per-date detail on the
/// per-course pages is deliberately not fetched; whoever needs it finds the
/// course in the portal browser.
///
/// Pushed from „Mehr", whose `NavigationStack` supplies the bar.
struct AttendanceView: View {
    @Environment(AppModel.self) private var model

    private var attendance: [CourseAttendance] { model.snapshot.attendance ?? [] }

    var body: some View {
        Group {
            let withAbsences = attendance.filter(\.hasAbsences)
            if withAbsences.isEmpty {
                EmptyStateView(icon: "checkmark.seal",
                               title: "Keine Fehlzeiten",
                               message: "In keinem Kurs ist etwas eingetragen. 🎉")
            } else {
                List {
                    Section("Gesamt") {
                        ForEach(totals) { total in
                            LabeledContent(Self.display(total.category)) {
                                Text(total.value)
                                    .foregroundStyle(total.isUnexcused && (total.number ?? 0) > 0
                                                     ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                                    .fontWeight(total.isUnexcused && (total.number ?? 0) > 0 ? .semibold : .regular)
                            }
                        }
                    }
                    Section {
                        ForEach(withAbsences) { course in
                            courseRow(course)
                        }
                    } header: {
                        Text("Nach Kurs")
                    } footer: {
                        if let last = model.snapshot.lastRefresh {
                            Text("Aus „Mein Unterricht\u{201C}, Stand \(last.formatted(date: .abbreviated, time: .shortened)). Kurse ohne Einträge sind ausgeblendet.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Fehlzeiten")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func courseRow(_ course: CourseAttendance) -> some View {
        // A non-numeric cell (nil) is an annotation worth showing, so only a
        // literal zero is dropped.
        let nonZero = course.counts.filter { ($0.number ?? 1) > 0 }
        let unexcused = nonZero.contains { $0.isUnexcused }
        return VStack(alignment: .leading, spacing: 3) {
            Text(courseName(course))
                .font(.body.weight(.medium))
            Text(nonZero.map { "\($0.value) \($0.category)" }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(unexcused ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
        .padding(.vertical, 2)
    }

    /// The subject resolution the rest of the app uses, when the course is
    /// known; the table's own title otherwise.
    private func courseName(_ course: CourseAttendance) -> String {
        model.snapshot.courses.first { $0.id == course.courseID }?.displayName
            ?? course.courseTitle
    }

    /// Category sums across all courses, in the table's own column order.
    /// Non-numeric cells (the portal sometimes prints annotations) are left
    /// out of the sum rather than guessed at.
    private var totals: [AttendanceCount] {
        var order: [String] = []
        var sums: [String: Int] = [:]
        for course in attendance {
            for count in course.counts {
                if sums[count.category] == nil {
                    order.append(count.category)
                    sums[count.category] = 0
                }
                sums[count.category]! += count.number ?? 0
            }
        }
        return order.map { AttendanceCount(category: $0, value: "\(sums[$0] ?? 0)") }
    }

    /// The portal's headers come lowercase ("fehlend"); only the first letter
    /// is raised so multi-word categories don't get title-cased into oddness.
    private static func display(_ category: String) -> String {
        guard let first = category.first else { return category }
        return first.uppercased() + category.dropFirst()
    }
}
