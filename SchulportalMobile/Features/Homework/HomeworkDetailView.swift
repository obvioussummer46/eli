import SwiftUI

struct HomeworkDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let homework: Homework

    @State private var openAttachment: Attachment?

    private var isDone: Bool { model.isDone(homework) }

    /// The lesson this homework was handed out in — gives the pupil the topic
    /// and any material the teacher attached.
    private var entry: LessonEntry? {
        model.snapshot.entries.first { $0.homework?.id == homework.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Card {
                        Text(homework.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    if let entry {
                        lessonCard(entry)
                        if !entry.attachments.isEmpty {
                            attachmentsCard(entry.attachments)
                        }
                    }
                    doneButton
                    footnote
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(homework.subject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $openAttachment) { attachment in
                DocumentSheet(attachment: attachment)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            SubjectChip(subject: homework.subject)
            Text(homework.courseTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let assigned = homework.assignedDate {
                Label("Aufgegeben am \(GermanDate.dayMonthYear.string(from: assigned))", systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let due = homework.dueDate {
                Label("Abgabe \(GermanDate.dayMonthYear.string(from: due))", systemImage: "flag")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(due < Date() && !isDone ? Color.red : Color.secondary)
            }
        }
    }

    private func lessonCard(_ entry: LessonEntry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Zur Stunde")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let topic = entry.topic {
                    Text(topic).font(.headline)
                }
                if let content = entry.content, !content.isEmpty {
                    Text(content)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func attachmentsCard(_ attachments: [Attachment]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Anhänge")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(attachments) { attachment in
                    Button {
                        openAttachment = attachment
                    } label: {
                        Label(attachment.name, systemImage: "paperclip")
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }

    private var doneButton: some View {
        Button {
            withAnimation(.snappy) { model.toggleDone(homework) }
        } label: {
            Label(isDone ? "Als offen markieren" : "Als erledigt markieren",
                  systemImage: isDone ? "arrow.uturn.backward" : "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isDone ? Color.orange : Color.green)
    }

    @ViewBuilder
    private var footnote: some View {
        if model.isPendingSync(homework) {
            Text("Der Haken ist gesetzt, konnte aber noch nicht ans Schulportal gemeldet werden. Die App versucht es beim nächsten Aktualisieren erneut.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if homework.portalEntryID == nil {
            Text("Diese Aufgabe lässt sich im Portal nicht abhaken – der Haken bleibt nur in der App.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
