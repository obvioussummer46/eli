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
            ZStack(alignment: .topLeading) {
                // Empty cells only where nothing is scheduled — the blocks
                // are translucent, so a cell underneath would shine through.
                let covered = coveredPeriods(for: day)
                VStack(spacing: 6) {
                    ForEach(periods, id: \.self) { period in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(covered.contains(period) ? Color.clear : Color(.secondarySystemGroupedBackground).opacity(0.5))
                            .frame(width: columnWidth, height: rowHeight)
                    }
                }
                // Overlapping entries — parallel courses, or an AG running
                // into the afternoon lessons — share the width in lanes
                // instead of the first one swallowing the rest.
                ForEach(placements(for: day)) { placed in
                    LessonBlock(entry: placed.entry)
                        .frame(width: laneWidth(lanes: placed.lanes), height: height(spanning: placed.entry))
                        .offset(x: CGFloat(placed.lane) * (laneWidth(lanes: placed.lanes) + laneSpacing),
                                y: rowOffset(of: placed.entry.firstPeriod))
                }
            }
            .frame(width: columnWidth, height: columnHeight, alignment: .topLeading)
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

    private let laneSpacing: CGFloat = 3

    private var columnHeight: CGFloat {
        guard !periods.isEmpty else { return 0 }
        return rowHeight * CGFloat(periods.count) + 6 * CGFloat(periods.count - 1)
    }

    private func rowOffset(of period: Int) -> CGFloat {
        guard let row = periods.firstIndex(of: period) else { return 0 }
        return CGFloat(row) * (rowHeight + 6)
    }

    private func height(spanning entry: TimetableEntry) -> CGFloat {
        let span = max(1, entry.lastPeriod - entry.firstPeriod + 1)
        return rowHeight * CGFloat(span) + 6 * CGFloat(span - 1)
    }

    private func laneWidth(lanes: Int) -> CGFloat {
        (columnWidth - laneSpacing * CGFloat(max(0, lanes - 1))) / CGFloat(max(1, lanes))
    }

    /// One entry placed in a lane. Entries whose periods overlap form a
    /// cluster and split that cluster's width evenly; everything else keeps
    /// the full column.
    private struct Placement: Identifiable {
        var entry: TimetableEntry
        var lane: Int
        var lanes: Int
        var id: String { entry.id }
    }

    private func coveredPeriods(for day: Weekday) -> Set<Int> {
        var covered = Set<Int>()
        for entry in timetable.entries(on: day) {
            covered.formUnion(entry.firstPeriod...max(entry.firstPeriod, entry.lastPeriod))
        }
        return covered
    }

    private func placements(for day: Weekday) -> [Placement] {
        // Lessons before activities, then the longer block first, so the
        // portal's plan keeps the left lane and an AG sits beside it.
        let lessons = timetable.entries(on: day).sorted {
            ($0.firstPeriod, $0.isActivity ? 1 : 0, -$0.lastPeriod) < ($1.firstPeriod, $1.isActivity ? 1 : 0, -$1.lastPeriod)
        }
        var clusters: [[TimetableEntry]] = []
        var current: [TimetableEntry] = []
        var currentEnd = Int.min
        for entry in lessons {
            if current.isEmpty || entry.firstPeriod <= currentEnd {
                current.append(entry)
                currentEnd = max(currentEnd, entry.lastPeriod)
            } else {
                clusters.append(current)
                current = [entry]
                currentEnd = entry.lastPeriod
            }
        }
        if !current.isEmpty { clusters.append(current) }

        var result: [Placement] = []
        for cluster in clusters {
            // Greedy: the first lane that is free again by the time the
            // entry starts, otherwise a new one.
            var laneEnds: [Int] = []
            var assigned: [(TimetableEntry, Int)] = []
            for entry in cluster {
                if let lane = laneEnds.firstIndex(where: { $0 < entry.firstPeriod }) {
                    laneEnds[lane] = entry.lastPeriod
                    assigned.append((entry, lane))
                } else {
                    laneEnds.append(entry.lastPeriod)
                    assigned.append((entry, laneEnds.count - 1))
                }
            }
            result += assigned.map { Placement(entry: $0.0, lane: $0.1, lanes: laneEnds.count) }
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
            if entry.isActivity {
                Text("\(SchoolActivity.subjectCode) · \(entry.start.description)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
