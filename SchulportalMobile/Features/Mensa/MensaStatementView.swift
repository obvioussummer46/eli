import SwiftUI

/// The account statement — the last month of bookings, newest first.
///
/// The site mixes two kinds of line into one list: money actually moving
/// (kiosk purchases, top-ups) and 0,00 € entries that only record that a menu
/// was collected. Both are worth seeing, so both are shown, but only the first
/// kind gets an amount.
struct MensaStatementView: View {
    @Environment(MensaModel.self) private var mensa

    var body: some View {
        List {
            Section {
                LabeledContent("Aktuelles Guthaben") {
                    Text(mensa.account.balanceDisplay)
                        .font(.headline)
                        .monospacedDigit()
                }
                if let last = mensa.lastRefresh {
                    LabeledContent("Zuletzt geladen",
                                   value: last.formatted(date: .omitted, time: .shortened))
                }
            }

            Section {
                if mensa.statement.transactions.isEmpty {
                    if mensa.isLoading {
                        Text("Wird geladen …")
                            .foregroundStyle(.secondary)
                    } else if mensa.statementErrorMessage != nil {
                        // "Keine Buchungen" would be a claim about the account.
                        // We do not know that — we know the list did not load.
                        Button("Nochmal laden") { Task { await mensa.refresh() } }
                    } else {
                        Text("Keine Buchungen.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(mensa.statement.transactions) { transaction in
                        MensaTransactionRow(transaction: transaction)
                    }
                }
            } header: {
                Text("Letzte 30 Tage")
            } footer: {
                if let message = mensa.statementErrorMessage {
                    Text("Der Kontoauszug ließ sich nicht laden. \(message)")
                }
            }
        }
        .navigationTitle("Kontoauszug")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await mensa.refresh() }
    }
}

private struct MensaTransactionRow: View {
    let transaction: MensaTransaction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(GermanDate.dayMonthYear.string(from: transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if transaction.isBooking {
                Text(MensaFormat.signedEuro(transaction.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(transaction.amount < 0 ? Color.primary : Color.green)
            } else {
                Image(systemName: "fork.knife")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
