import ActivityKit
import SwiftUI
import WidgetKit

/// The school day on the lock screen and in the Dynamic Island: the running
/// lesson with a countdown to its end, or the next one with a countdown to
/// its start. Rendered from `LessonActivityAttributes` — updates come only
/// when the app runs, so the view leans on system-driven timers and shows a
/// gentle hint once the content went stale.
struct LessonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivityAttributes.self) { context in
            LessonActivityLockView(state: context.state, isStale: context.isStale)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.55))
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
                    if let next = context.state.nextSubject {
                        Text("Danach: \(next)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Circle()
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 10, height: 10)
            } compactTrailing: {
                LessonCountdown(state: context.state)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                Circle()
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 10, height: 10)
            }
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
                Text(state.isOngoing ? "Gerade" : "Als Nächstes")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(state.subject)
                    .font(.title3.bold())
                    .lineLimit(1)
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
