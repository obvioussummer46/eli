import ActivityKit
import SwiftUI
import WidgetKit

/// The school day on the lock screen and in the Dynamic Island: the running
/// lesson with a countdown to its end, or the next one with a countdown to
/// its start — plus what the Vertretungsplan says about it and the subject's
/// open homework, tickable in place. Rendered from `LessonActivityAttributes`
/// — updates come only when the app runs, so the view leans on system-driven
/// timers and shows a gentle hint once the content went stale.
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
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: context.state.colorHex))
                        .frame(width: 4, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.subject)
                            .font(.headline)
                            .strikethrough(context.state.isCancelled)
                            .lineLimit(1)
                        if let room = context.state.room, !room.isEmpty {
                            Text(room)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            DynamicIslandExpandedRegion(.trailing) {
                LessonCountdown(state: context.state)
                    .font(.title3.monospacedDigit())
            }
            DynamicIslandExpandedRegion(.bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    if let kind = context.state.substitutionKind {
                        SubstitutionLine(kind: kind,
                                         detail: context.state.substitutionDetail,
                                         isCancelled: context.state.isCancelled)
                    }
                    if context.state.homeworkID != nil {
                        HomeworkTickRow(state: context.state)
                    } else if context.state.substitutionKind == nil,
                              let next = context.state.nextSubject {
                        Text("Danach: \(next)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } compactLeading: {
            if context.state.substitutionKind != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(context.state.isCancelled ? .red : .orange)
            } else {
                Circle()
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 10, height: 10)
            }
        } compactTrailing: {
            LessonCountdown(state: context.state)
                .font(.caption2.monospacedDigit())
                .frame(maxWidth: 44)
        } minimal: {
            if context.state.substitutionKind != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(context.state.isCancelled ? .red : .orange)
            } else {
                Circle()
                    .fill(Color(hex: context.state.colorHex))
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
            LessonActivitySmallView(state: state)
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
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: state.colorHex))
                .frame(width: 5, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(state.statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let kind = state.substitutionKind {
                        Text(kind)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background((state.isCancelled ? Color.red : Color.orange).opacity(0.35),
                                        in: Capsule())
                    }
                }
                Text(state.subject)
                    .font(.title3.bold())
                    .strikethrough(state.isCancelled)
                    .lineLimit(1)
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
                        if let next = state.nextSubject {
                            Text("Danach: \(next)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                if state.homeworkID != nil {
                    HomeworkTickRow(state: state)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if isStale {
                    Text("Stunde vorbei")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LessonCountdown(state: state)
                        .font(.title3.bold().monospacedDigit())
                        .frame(maxWidth: 64)
                    Text(state.isOngoing ? "bis \(timeLabel(state.end))" : "ab \(timeLabel(state.start))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func timeLabel(_ date: Date) -> String {
        let cal = SharedSnapshot.calendar
        return String(format: "%02d:%02d",
                      cal.component(.hour, from: date),
                      cal.component(.minute, from: date))
    }
}

/// The Smart Stack on the watch: one glance, no buttons — CarPlay renders
/// this layout too and deactivates anything interactive.
private struct LessonActivitySmallView: View {
    let state: LessonActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: state.colorHex))
                    .frame(width: 8, height: 8)
                Text(state.statusLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                LessonCountdown(state: state)
                    .font(.caption.bold().monospacedDigit())
                    .frame(maxWidth: 52)
            }
            Text(state.subject)
                .font(.headline)
                .strikethrough(state.isCancelled)
                .lineLimit(1)
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

/// System-driven countdown — ticks without any update from the app: to the
/// lesson's end while it runs, to its start while it is still ahead.
private struct LessonCountdown: View {
    let state: LessonActivityAttributes.ContentState

    var body: some View {
        Text(timerInterval: Date()...(state.isOngoing ? state.end : state.start),
             countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}
