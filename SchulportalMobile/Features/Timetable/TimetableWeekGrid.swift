import SwiftUI

/// The whole week at a glance — a scrollable grid where a double lesson is one
/// tall block, exactly as in the portal.
struct TimetableWeekGrid: View {
    let timetable: Timetable

    private let rowHeight: CGFloat = 62
    private let columnWidth: CGFloat = 108
    private let timeColumnWidth: CGFloat = 48

    private var days: [Weekday] {
        let used = timetable.weekdaysInUse
        return used.isEmpty ? [.monday, .tuesday, .wednesday, .thursday, .friday] : used
    }

    private var periods: [Int] {
        let fromEntries = timetable.entries.flatMap { [$0.firstPeriod, $0.lastPeriod] }
        guard let lower = fromEntries.min(), let upper = fromEntries.max() else { return [] }
        return Array(lower...upper)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 6) {
                timeColumn
                ForEach(days) { day in
                    dayColumn(day)
                }
            }
            .padding(16)
        }
    }

    private var timeColumn: some View {
        VStack(spacing: 6) {
            header(Text(""))
            ForEach(periods, id: \.self) { period in
                VStack(spacing: 1) {
                    Text("\(period)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if let start = startTime(of: period) {
                        Text(start.description)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: timeColumnWidth, height: rowHeight)
            }
        }
    }

    private func dayColumn(_ day: Weekday) -> some View {
        VStack(spacing: 6) {
            header(Text(day.shortName).font(.subheadline.weight(.semibold)))
            ForEach(slots(for: day), id: \.period) { slot in
                if !slot.entries.isEmpty {
                    // Parallel courses (Religion/Ethik, second languages)
                    // share the slot side by side instead of the first one
                    // silently swallowing the rest.
                    HStack(spacing: 3) {
                        ForEach(slot.entries) { entry in
                            LessonBlock(entry: entry)
                        }
                    }
                    .frame(width: columnWidth,
                           height: rowHeight * CGFloat(slot.span) + 6 * CGFloat(slot.span - 1))
                } else if !slot.isCovered {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.5))
                        .frame(width: columnWidth, height: rowHeight)
                }
            }
        }
    }

    private func header(_ label: some View) -> some View {
        label
            .frame(width: columnWidth, height: 26)
            .foregroundStyle(.secondary)
    }

    private func startTime(of period: Int) -> TimeOfDay? {
        timetable.periods.first { $0.index == period }?.start
            ?? timetable.entries.first { $0.firstPeriod == period }?.start
    }

    // MARK: - Layout

    private struct Slot {
        var period: Int
        /// Everything starting in this period — more than one when courses
        /// run in parallel.
        var entries: [TimetableEntry]
        var span: Int
        /// A row swallowed by the block above it — renders nothing at all.
        var isCovered: Bool
    }

    private func slots(for day: Weekday) -> [Slot] {
        let lessons = timetable.entries(on: day)
        var result: [Slot] = []
        var coveredUntil = Int.min

        for period in periods {
            if period <= coveredUntil {
                result.append(Slot(period: period, entries: [], span: 1, isCovered: true))
                continue
            }
            let starting = lessons.filter { $0.firstPeriod == period }
            if let longest = starting.map(\.lastPeriod).max() {
                let span = max(1, longest - period + 1)
                coveredUntil = longest
                result.append(Slot(period: period, entries: starting, span: span, isCovered: false))
            } else {
                result.append(Slot(period: period, entries: [], span: 1, isCovered: false))
            }
        }
        return result
    }
}

private struct LessonBlock: View {
    let entry: TimetableEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.subject.name)
                .font(.caption.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let room = entry.room, !room.isEmpty {
                Text(room)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let teacher = entry.teacher, !teacher.isEmpty {
                Text(teacher)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(entry.subject.color.opacity(0.14), in: .rect(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(entry.subject.color)
                .frame(width: 3)
        }
        .clipShape(.rect(cornerRadius: 10))
    }
}
