import SwiftUI
import UIKit

struct HomeworkRow: View {
    @Environment(AppModel.self) private var model
    let homework: Homework

    private var isDone: Bool { model.isDone(homework) }

    /// Only a real deadline counts as overdue — the date a task was *given* out
    /// is always in the past and must not turn the row red.
    private var isOverdue: Bool {
        guard let due = homework.dueDate, !isDone else { return false }
        return due < GermanDate.calendar.startOfDay(for: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.snappy) { model.toggleDone(homework) }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Als offen markieren" : "Als erledigt markieren")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    SubjectChip(subject: homework.subject)
                    Spacer(minLength: 4)
                    if model.isPendingSync(homework) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Noch nicht ans Portal übertragen")
                    }
                    if let date = homework.effectiveDate {
                        Text(dateLabel(date))
                            .font(.caption)
                            .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                    }
                }
                Text(homework.text)
                    .font(.callout)
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
                    .strikethrough(isDone, color: .secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }

    private func dateLabel(_ date: Date) -> String {
        let prefix = homework.dueDate != nil ? "bis " : ""
        return prefix + GermanDate.relativeLabel(for: date)
    }
}
