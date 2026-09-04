import SwiftUI

/// The list the whole app exists for: every open homework, one tap to tick off.
struct HomeworkListView: View {
    @Environment(AppModel.self) private var model
    @Environment(Store.self) private var store
    @State private var searchText = ""
    @State private var shareFile: ShareFile?
    @State private var isShowingPaywall = false
    @State private var subjectFilter: String?
    @State private var selection: Homework?

    var body: some View {
        let settings = model.settings

        NavigationStack {
            List {
                if let message = model.lastErrorMessage {
                    Section {
                        InlineErrorBanner(message: message) {
                            Task { await model.refresh() }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }

                if open.isEmpty && done.isEmpty {
                    Section {
                        if let notice = model.accountNotice {
                            // The truthful reason the list is empty — not a
                            // cheery "nichts Offenes" the account could
                            // never have shown.
                            EmptyStateView(icon: "person.2",
                                           title: "Kein „Mein Unterricht“",
                                           message: notice)
                            .listRowBackground(Color.clear)
                        } else {
                            EmptyStateView(icon: "checkmark.seal",
                                           title: model.snapshot.lastRefresh == nil ? "Noch nichts geladen" : "Keine Hausaufgaben",
                                           message: model.snapshot.lastRefresh == nil
                                                ? "Zieh die Liste nach unten, um „Mein Unterricht“ zu laden."
                                                : "Im Portal steht gerade nichts Offenes.")
                            .listRowBackground(Color.clear)
                        }
                    }
                } else {
                    Section {
                        ForEach(open) { item in
                            row(item)
                        }
                    } header: {
                        Text(open.isEmpty ? "Offen" : "Offen · \(open.count)")
                    } footer: {
                        if open.isEmpty {
                            Text("Alles abgehakt. 🎉")
                        }
                    }

                    if !settings.hidesDoneHomework, !done.isEmpty {
                        Section("Erledigt · \(done.count)") {
                            ForEach(done) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hausaufgaben")
            .searchable(text: $searchText, prompt: "Aufgabe oder Fach suchen")
            .refreshable { await model.refresh() }
            .toolbar { toolbar(settings: settings) }
            .sheet(item: $shareFile) { file in
                ShareSheet(items: [file.url])
            }
            .paywall(isPresented: $isShowingPaywall)
            .sheet(item: $selection) { item in
                HomeworkDetailView(homework: item)
                    .environment(model)
            }
            .overlay(alignment: .bottom) {
                if model.isRefreshing {
                    RefreshPill()
                }
            }
        }
    }

    private func row(_ item: Homework) -> some View {
        HomeworkRow(homework: item)
            .onTapGesture { selection = item }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    withAnimation(.snappy) { model.toggleDone(item) }
                } label: {
                    Label(model.isDone(item) ? "Offen" : "Erledigt",
                          systemImage: model.isDone(item) ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(model.isDone(item) ? Color.orange : Color.green)
            }
    }

    @ToolbarContentBuilder
    private func toolbar(settings: Settings) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Fach", selection: $subjectFilter) {
                    Text("Alle Fächer").tag(String?.none)
                    ForEach(subjects, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
                Toggle("Erledigte ausblenden", isOn: Binding(
                    get: { settings.hidesDoneHomework },
                    set: { settings.hidesDoneHomework = $0 }
                ))
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
                Divider()
                // Export is Pro. Shown to everyone, so it can be found;
                // locked, the tap explains itself on the paywall.
                if store.entitlements.isPro {
                    Menu {
                        ForEach(HomeworkExport.Format.allCases) { format in
                            Button {
                                let items = open + (settings.hidesDoneHomework ? [] : done)
                                if let url = HomeworkExport.file(format, items: items, model: model) {
                                    shareFile = ShareFile(url: url)
                                }
                            } label: {
                                Label(format.title, systemImage: format.systemImage)
                            }
                        }
                    } label: {
                        Label("Exportieren", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        isShowingPaywall = true
                    } label: {
                        Label("Exportieren (Pro)", systemImage: "lock")
                    }
                }
            } label: {
                Image(systemName: subjectFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    // MARK: - Data

    private var subjects: [String] {
        Array(Set(model.allHomework.map(\.subject.name))).sorted()
    }

    private var open: [Homework] { filter(model.openHomework) }
    private var done: [Homework] { filter(model.doneHomework) }

    private func filter(_ items: [Homework]) -> [Homework] {
        items.filter { item in
            if let subjectFilter, item.subject.name != subjectFilter { return false }
            guard !searchText.isEmpty else { return true }
            return item.text.localizedCaseInsensitiveContains(searchText)
                || item.subject.name.localizedCaseInsensitiveContains(searchText)
                || item.courseTitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct RefreshPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Wird geladen …").font(.footnote)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: .capsule)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
