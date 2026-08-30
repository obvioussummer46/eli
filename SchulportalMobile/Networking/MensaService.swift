import Foundation

/// Fetch + parse, one method per page — the mensa counterpart to
/// `PortalService`.
struct MensaService {
    private let client: MensaClient

    init(client: MensaClient = .shared) {
        self.client = client
    }

    // MARK: - Session

    func signIn(_ credentials: MensaCredentials) async throws {
        try await client.signIn(credentials)
    }

    func adopt(_ credentials: MensaCredentials?) async {
        await client.adopt(credentials)
    }

    func signOut() async {
        await client.forget()
    }

    // MARK: - Speiseplan

    /// Pass `nil` for whatever week the site considers current.
    func loadWeek(_ week: String?) async throws -> SpeiseplanParser.Result {
        let html = try await client.html(MensaEndpoints.speiseplan(week: week))
        return try SpeiseplanParser.parse(html: html)
    }

    // MARK: - Guthaben

    /// Balance plus the last month of bookings — the two calls the site's own
    /// "Guthaben" page makes.
    ///
    /// The balance is best-effort: `speiseplan.php` already put a figure on
    /// screen, so a failing overview call is not worth losing the statement
    /// over. A failing *statement* is reported, because an empty list would
    /// otherwise read as "you have not eaten in a month".
    func loadStatement(days: Int = 30, pageSize: Int = 100) async throws -> MensaStatement {
        async let overview = client.getJSON(MensaEndpoints.accountOverview)
        async let bookings = transactions(days: days, pageSize: pageSize)

        var statement = MensaStatement()
        if let data = try? await overview {
            let account = MensaStatementParser.account(from: data)
            statement.balance = account.balance
            statement.balanceText = account.balance.map(Self.germanString)
            statement.lowBalanceThreshold = account.lowBalanceThreshold
        }
        statement.transactions = try await bookings
        return statement
    }

    /// The bookings of the last `days` days.
    ///
    /// The date range is the fragile part. `berichte_api.php` is German-facing
    /// PHP: handed a range it cannot read, it answers "nothing found" rather
    /// than an error, and that is indistinguishable from an account that simply
    /// has no bookings — which is exactly how the statement came to be
    /// permanently empty. So an empty answer is not believed until the other
    /// two spellings the site's own filter uses have been tried as well. Only
    /// the first request happens in the normal case.
    private func transactions(days: Int, pageSize: Int) async throws -> [MensaTransaction] {
        let today = Date()
        let from = GermanDate.calendar.date(byAdding: .day, value: -days, to: today) ?? today

        let ranges = [
            (Self.isoDay.string(from: from), Self.isoDay.string(from: today)),
            (GermanDate.dayMonthYear.string(from: from), GermanDate.dayMonthYear.string(from: today)),
            // The site's "Alle" preset: no range at all.
            ("", "")
        ]

        var recognisedAnAnswer = false
        for range in ranges {
            let data = try await client.postJSON(MensaEndpoints.transactions,
                                                 body: Self.searchBody(from: range.0,
                                                                       to: range.1,
                                                                       pageSize: pageSize))
            let bookings = MensaStatementParser.bookings(from: data)
            if !bookings.transactions.isEmpty { return bookings.transactions }
            recognisedAnAnswer = recognisedAnAnswer || bookings.isRecognised
        }

        // Nothing came back that even looked like a list of bookings. Reporting
        // that as „Keine Buchungen“ would be the app inventing a fact about the
        // account, which is how this went unnoticed the first time.
        guard recognisedAnAnswer else { throw MensaError.parsing("Der Guthabenverlauf") }
        return []
    }

    /// The exact filter the site posts. `type` and `direction` are sent empty
    /// on purpose — that is what the "Alle" preset does.
    private static func searchBody(from: String, to: String, pageSize: Int) -> [String: Any] {
        [
            "type": "",
            "direction": "",
            "dateFrom": from,
            "dateTo": to,
            "valutaFrom": "",
            "valutaTo": "",
            "orderBy": ["column": "t.id", "orderType": "DESC"],
            "page": 1,
            "pageSize": pageSize
        ]
    }

    // MARK: - Wire format

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = GermanDate.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func germanString(_ value: Decimal) -> String {
        MensaFormat.amount.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

/// Money, the way the site prints it.
enum MensaFormat {
    static let amount: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func euro(_ value: Decimal) -> String {
        let number = amount.string(from: value as NSDecimalNumber) ?? "\(value)"
        return "\(number) €"
    }

    /// Signed, for the statement: `+ 20,00 €` / `− 1,50 €`.
    static func signedEuro(_ value: Decimal) -> String {
        let magnitude = value < 0 ? -value : value
        let sign = value < 0 ? "−" : "+"
        return "\(sign) \(euro(magnitude))"
    }
}
