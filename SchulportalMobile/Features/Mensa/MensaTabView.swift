import SwiftUI

/// The „Essen“ tab: what the mensa is cooking this week, what is ordered, and
/// what is left on the card.
///
/// Read-only by design. Picking a menu costs real money, so the app shows the
/// selection the website holds but never changes it.
struct MensaTabView: View {
    @Environment(MensaModel.self) private var mensa
    @State private var selectedDayID: String?
    @State private var isConfirmingSignOut = false

    var body: some View {
        NavigationStack {
            Group {
                switch mensa.phase {
                case .launching:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                case .signedOut:
                    MensaLoginView()
                case .ready:
                    content
                }
            }
            .navigationTitle("Essen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mensa.phase == .ready {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                Task { await mensa.refresh() }
                            } label: {
                                Label("Aktualisieren", systemImage: "arrow.clockwise")
                            }
                            Link(destination: MensaEndpoints.speiseplan(week: nil)) {
                                Label("Auf menuebestellung.de", systemImage: "safari")
                            }
                            Divider()
                            Button(role: .destructive) {
                                isConfirmingSignOut = true
                            } label: {
                                Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog("Vom Bestellsystem abmelden?",
                                isPresented: $isConfirmingSignOut,
                                titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) {
                    Task { await mensa.signOut() }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die gespeicherten Zugangsdaten werden dabei aus dem Schlüsselbund gelöscht.")
            }
        }
        .task {
            if mensa.phase == .launching { await mensa.bootstrap() }
        }
    }

    // MARK: - Signed in

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                MensaBalanceCard()

                // Only a failing plan page earns a banner; a failing account
                // statement stays in the Kontoauszug, which is the only screen
                // it affects.
                if let message = mensa.weekErrorMessage {
                    InlineErrorBanner(message: message) {
                        Task { await mensa.refresh() }
                    }
                }

                if mensa.week.days.isEmpty {
                    if mensa.isLoading {
                        ProgressView().padding(.vertical, 40)
                    } else {
                        EmptyStateView(icon: "fork.knife",
                                       title: "Kein Speiseplan",
                                       message: "Für diese Woche hat menuebestellung.de nichts veröffentlicht.")
                    }
                } else {
                    weekPager
                    dayPicker
                    dayMenus
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await mensa.refresh() }
        .onChange(of: mensa.week.key) { _, _ in syncSelectedDay(force: true) }
        .onAppear { syncSelectedDay(force: false) }
    }

    // MARK: - Week

    private var weekPager: some View {
        HStack {
            Button {
                if let previous = mensa.previousWeek { Task { await mensa.selectWeek(previous.key) } }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(mensa.previousWeek == nil)

            Spacer(minLength: 8)

            Menu {
                ForEach(mensa.week.availableWeeks) { option in
                    Button {
                        Task { await mensa.selectWeek(option.key) }
                    } label: {
                        if option.key == mensa.week.key {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                Text(mensa.week.label.isEmpty ? "Speiseplan" : mensa.week.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                if let next = mensa.nextWeek { Task { await mensa.selectWeek(next.key) } }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(mensa.nextWeek == nil)
        }
        .padding(.horizontal, 4)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mensa.week.days) { day in
                    MensaDayChip(day: day,
                                 isSelected: day.id == selectedDayID,
                                 isToday: day.id == mensa.todaysDay?.id)
                    .onTapGesture { selectedDayID = day.id }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var dayMenus: some View {
        if let day = mensa.week.days.first(where: { $0.id == selectedDayID }) {
            VStack(spacing: 12) {
                if day.options.isEmpty {
                    EmptyStateView(icon: "fork.knife",
                                   title: "Kein Angebot",
                                   message: "An diesem Tag gibt es kein Menü.")
                } else {
                    ForEach(day.options) { option in
                        MensaMenuCard(option: option,
                                      isOrdered: option.id == day.orderedOptionID,
                                      isLocked: day.isLocked)
                    }
                    MensaOrderHint(day: day)
                }
            }
        }
    }

    /// Keeps the day picker pointing at something that exists — on first
    /// appearance, and again whenever the week changes underneath it.
    private func syncSelectedDay(force: Bool) {
        let ids = Set(mensa.week.days.map(\.id))
        if force || selectedDayID == nil || !ids.contains(selectedDayID ?? "") {
            selectedDayID = mensa.defaultDayID
        }
    }
}
