import Foundation

/// `berichte_api.php` → balance and bookings.
///
/// The endpoint is the one part of the Essen tab that is a real JSON API rather
/// than scraped HTML, which made it tempting to decode strictly. It should not
/// have been: see `MensaJSON` for what the back end actually sends. Everything
/// here therefore reads fields by meaning and drops only the individual rows it
/// cannot make sense of, never the whole list.
enum MensaStatementParser {
    /// The `?getPageData` answer: what is on the card, and the figure the site
    /// itself starts warning at.
    static func account(from data: Data) -> (balance: Decimal?, lowBalanceThreshold: Decimal?) {
        guard let object = MensaJSON.value(of: data) as? [String: Any] else { return (nil, nil) }
        let row = MensaJSON.Row(object)

        let balance = row.decimal(balanceKeys)
            ?? row.row(["account", "data", "pageData", "result"])?.decimal(balanceKeys)

        let threshold = row.row(thresholdKeys)?.decimal(["minimumBalance", "minimum", "value", "amount"])
            ?? row.decimal(["minimumBalance"])

        return (balance, threshold)
    }

    /// What one `?searchTransactions` answer contained.
    struct Bookings {
        var transactions: [MensaTransaction] = []
        /// The answer held a record list — even an empty one. `false` means we
        /// did not recognise the answer at all, which is a different thing
        /// entirely from an account that has not been used.
        var isRecognised = false
    }

    /// The `?searchTransactions` answer, newest first as the site sorts it.
    static func bookings(from data: Data) -> Bookings {
        let payload = MensaJSON.value(of: data)
        let rows = MensaJSON.rows(in: payload, where: looksLikeTransaction)
        return Bookings(
            transactions: rows.enumerated().compactMap { transaction(from: $0.element, position: $0.offset) },
            isRecognised: !rows.isEmpty || MensaJSON.containsList(in: payload)
        )
    }

    // MARK: - Field names

    private static let balanceKeys = ["totalBalance", "balance", "currentBalance", "guthaben", "saldo", "kontostand"]
    private static let thresholdKeys = ["lowBalanceThreshold", "lowBalance", "warnThreshold", "minBalance"]

    private static let dateKeys = ["datetime", "dateTime", "date", "bookingDate", "buchungsdatum", "buchungstag",
                                   "valuta", "valutaDate", "created", "createdAt", "timestamp", "datum"]
    private static let valueKeys = ["value", "amount", "betrag", "sum", "wert", "umsatz"]
    private static let textKeys = ["description", "text", "title", "purpose", "verwendungszweck",
                                   "bezeichnung", "article", "artikel", "name", "info"]
    private static let idKeys = ["id", "transactionId", "bookingId", "t.id", "nr", "number"]

    /// A record counts as a booking when it is dated and carries either an
    /// amount or a description. Requiring both would drop the site's 0,00 €
    /// pick-up lines on routes that omit the empty amount entirely.
    private static func looksLikeTransaction(_ row: MensaJSON.Row) -> Bool {
        guard row.date(dateKeys) != nil else { return false }
        return row.has(valueKeys) || row.has(textKeys)
    }

    private static func transaction(from row: MensaJSON.Row, position: Int) -> MensaTransaction? {
        guard let date = row.date(dateKeys) else { return nil }
        let amount = row.decimal(valueKeys) ?? 0
        let text = row.string(textKeys) ?? "Buchung"
        // The site's own id when it sends one; otherwise something stable
        // enough for `ForEach` that two identical bookings on one day still
        // count as two rows.
        let id = row.string(idKeys)
            ?? StableHash.string("\(position)|\(date.timeIntervalSince1970)|\(text)|\(amount)")
        return MensaTransaction(id: id, date: date, text: text, amount: amount)
    }
}
