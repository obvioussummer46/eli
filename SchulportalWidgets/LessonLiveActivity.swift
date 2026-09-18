import ActivityKit
import SwiftUI
import WidgetKit

/// The school day on the lock screen and in the Dynamic Island: the running
/// lesson with a countdown to its end, or the next one with a countdown to
/// its start — plus what the Vertretungsplan says about it and the subject's
/// open homework, tickable in place.
///
/// There is no push channel: updates come only when the app runs, and the
/// system grants exactly one extra render at `staleDate`. Every view here
/// therefore draws by `Moment` (see `LessonActivityAttributes.ContentState`),
/// so an expired countdown flips to the pause, the started lesson, or the
/// end of the school day — never to a frozen 0:00.
///
/// The `supplementalActivityFamilies` declaration (iOS 18) cannot be applied
/// conditionally inside one Widget — `Widget.body` is a plain property, so
/// `if #available` branches must have equal types. Hence two widgets around
/// the same configuration; `WidgetsBundle` registers exactly one of them.
struct LessonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        lessonActivityConfiguration()
    }
}

/// The iOS 18 variant: additionally declares the watch's small family, so
/// the Smart Stack renders `LessonActivitySmallView` instead of the system
/// default built from the compact island views.
@available(iOSApplicationExtension 18.0, *)
struct SupplementedLessonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        lessonActivityConfiguration()
            .supplementalActivityFamilies([.small])
    }
}

private func lessonActivityConfiguration() -> some WidgetConfiguration {
    ActivityConfiguration(for: LessonActivityAttributes.self) { context in
        LessonActivityContent(state: context.state, isStale: context.isStale)
    } dynamicIsland: { context in
        let state = context.state
        let moment = state.moment(isStale: context.isStale)
        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: state.colorHex))
                        .frame(width: 4, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.title(for: moment))
                            .font(.headline)
                            .strikethrough(state.isCancelled && state.showsLessonDetails(for: moment))
                            .lineLimit(1)
                        if state.showsLessonDetails(for: moment) {
                            let detail = [state.room,
                                          state.periodLabel.map { "\($0) Std." }]
                                .compactMap { $0 }.filter { !$0.isEmpty }
                            if !detail.isEmpty {
                                Text(detail.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            DynamicIslandExpandedRegion(.trailing) {
                if let target = state.countdownTarget(for: moment) {
                    LessonCountdown(target: target)
                        .font(.title3.monospacedDigit())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            }
            DynamicIslandExpandedRegion(.bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    if state.showsLessonDetails(for: moment) {
                        if let kind = state.substitutionKind {
                            SubstitutionLine(kind: kind,
                                             detail: state.substitutionDetail,
                                             isCancelled: state.isCancelled)
                        }
                        if state.homeworkID != nil {
                            HomeworkTickRow(state: state)
                        } else if state.substitutionKind == nil,
                                  let followUp = state.followUpLine {
                            Text(followUp)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if moment == .pause, let dayEnd = state.dayEnd {
                        Text("Schluss \(LessonActivityAttributes.ContentState.timeLabel(dayEnd))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } compactLeading: {
            // A bare dot said nothing about *what* is running. The subject,
            // tail-truncated — the compact view cannot grow in width in
            // iOS 27's landscape island.
            HStack(spacing: 4) {
                if state.substitutionKind != nil, state.showsLessonDetails(for: moment) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(state.isCancelled ? .red : .orange)
                } else {
                    Circle()
                        .fill(Color(hex: state.colorHex))
                        .frame(width: 8, height: 8)
                }
                Text(state.compactTitle(for: moment))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: 84)
        } compactTrailing: {
            if let target = state.countdownTarget(for: moment) {
                LessonCountdown(target: target)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 44)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        } minimal: {
            if moment == .over {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else if state.substitutionKind != nil, state.showsLessonDetails(for: moment) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(state.isCancelled ? .red : .orange)
            } else {
                Circle()
                    .fill(Color(hex: state.colorHex))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

/// Chooses the presentation: the lock-screen card on iPhone, the tighter
/// small-family card once the activity travels to the Apple Watch Smart
/// Stack (iOS 18's supplemental family).
private struct LessonActivityContent: View {
    let state: LessonActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if #available(iOSApplicationExtension 18.0, *) {
            FamilyPickedContent(state: state, isStale: isStale)
        } else {
            lockCard
        }
    }

    private var lockCard: some View {
        LessonActivityLockView(state: state, isStale: isStale)
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.55))
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct FamilyPickedContent: View {
    @Environment(\.activityFamily) private var family
    let state: LessonActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        switch family {
        case .small:
            LessonActivitySmallView(state: state, isStale: isStale)
                .padding(10)
        default:
            LessonActivityLockView(state: state, isStale: isStale)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.55))
        }
    }
}

private struct LessonActivityLockView: View {
    let state: LessonActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let moment = state.moment(isStale: isStale)
        let showsDetails = state.showsLessonDetails(for: moment)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: state.colorHex))
                .frame(width: 5, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(state.statusLine(for: moment))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let kind = state.substitutionKind, showsDetails {
                        Text(kind)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background((state.isCancelled ? Color.red : Color.orange).opacity(0.35),
                                        in: Capsule())
                    }
                }
                Text(state.title(for: moment))
                    .font(.title3.bold())
                    .strikethrough(state.isCancelled && showsDetails)
                    .lineLimit(1)
                if showsDetails {
                    if let detail = state.substitutionDetail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(state.isCancelled ? .red : .orange)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 8) {
                            if let room = state.room, !room.isEmpty {
                                Label(room, systemImage: "mappin.and.ellipse")
                            }
                            if let followUp = state.followUpLine {
                                Text(followUp)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    if state.homeworkID != nil {
                        HomeworkTickRow(state: state)
                    }
                } else if moment == .pause, let dayEnd = state.dayEnd {
                    Text("Schluss \(LessonActivityAttributes.ContentState.timeLabel(dayEnd))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let target = state.countdownTarget(for: moment) {
                    LessonCountdown(target: target)
                        .font(.title3.bold().monospacedDigit())
                        .frame(maxWidth: 64)
                    Text(trailingLabel(for: moment, target: target))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
        }
        .foregroundStyle(.white)
    }

    /// "bis 10:40" under a running countdown, "ab 10:55" under a waiting one.
    private func trailingLabel(for moment: LessonActivityAttributes.ContentState.Moment,
                               target: Date) -> String {
        let time = LessonActivityAttributes.ContentState.timeLabel(target)
        return moment == .running ? "bis \(time)" : "ab \(time)"
    }
}

/// The Smart Stack on the watch: one glance, no buttons — CarPlay renders
/// this layout too and deactivates anything interactive.
private struct LessonActivitySmallView: View {
    let state: LessonActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let moment = state.moment(isStale: isStale)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: state.colorHex))
                    .frame(width: 8, height: 8)
                Text(state.statusLine(for: moment))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let target = state.countdownTarget(for: moment) {
                    LessonCountdown(target: target)
                        .font(.caption.bold().monospacedDigit())
                        .frame(maxWidth: 52)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Text(state.title(for: moment))
                .font(.headline)
                .strikethrough(state.isCancelled && state.showsLessonDetails(for: moment))
                .lineLimit(1)
            if state.showsLessonDetails(for: moment) {
                if let kind = state.substitutionKind {
                    Text([kind, state.substitutionDetail].compactMap(\.self).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(state.isCancelled ? .red : .orange)
                        .lineLimit(1)
                } else if let room = state.room, !room.isEmpty {
                    Text(room)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// "Entfall · R101 → R204 · bei Hr. X" — the plan's word first, then the
/// row's summary, in the badge's warning colour.
private struct SubstitutionLine: View {
    let kind: String
    let detail: String?
    let isCancelled: Bool

    var body: some View {
        Text([kind, detail].compactMap(\.self).joined(separator: " · "))
            .font(.caption.weight(.semibold))
            .foregroundStyle(isCancelled ? .red : .orange)
            .lineLimit(1)
    }
}

/// The subject's open homework with its tick. The intent runs in the app's
/// process and flips `homeworkDone` on the activity right away, so the row
/// answers the tap without waiting for the next sync.
private struct HomeworkTickRow: View {
    let state: LessonActivityAttributes.ContentState

    var body: some View {
        if let id = state.homeworkID, let text = state.homeworkText {
            let done = state.homeworkDone ?? false
            Button(intent: MarkActivityHomeworkDoneIntent(homeworkID: id)) {
                HStack(spacing: 5) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? .green : .secondary)
                    Text("HA: \(text)")
                        .strikethrough(done)
                        .foregroundStyle(done ? .secondary : .primary)
                        .lineLimit(1)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(done)
        }
    }
}

/// System-driven countdown to a moment's target — ticks without any update
/// from the app.
private struct LessonCountdown: View {
    let target: Date

    var body: some View {
        Text(timerInterval: Date()...max(target, Date()), countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}
