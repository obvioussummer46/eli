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
    func loadStatement(days: Int = 30, pageSize: Int = 50) async throws -> MensaStatement {
        async let overview = client.getJSON(MensaEndpoints.accountOverview)
        async let entries = client.postJSON(MensaEndpoints.transactions,
                                            body: Self.searchBody(days: days, pageSize: pageSize))

        var statement = MensaStatement()

        let overviewData = try await overview
        if let payload = try? JSONDecoder().decode(OverviewPayload.self, from: overviewData) {
            statement.balance = Decimal(string: payload.totalBalance ?? payload.balance ?? "")
            statement.balanceText = statement.balance.map(Self.germanString)
            statement.lowBalanceThreshold = payload.lowBalanceThreshold?.minimumBalance.flatMap { Decimal(string: $0) }
        }

        let entriesData = try await entries
        guard let payload = try? JSONDecoder.portal.decode(TransactionsPayload.self, from: entriesData) else {
            throw MensaError.parsing("Der Guthabenverlauf")
        }
        statement.transactions = payload.data.compactMap(\.model)
        return statement
    }

    /// The exact filter the site posts: everything, newest first, last `days`
    /// days. `type` and `direction` are sent empty on purpose — that is what
    /// the "Alle" preset does.
    private static func searchBody(days: Int, pageSize: Int) -> [String: Any] {
        let today = Date()
        let from = GermanDate.calendar.date(byAdding: .day, value: -days, to: today) ?? today
        return [
            "type": "",
            "direction": "",
            "dateFrom": isoDay.string(from: from),
            "dateTo": isoDay.string(from: today),
            "valutaFrom": "",
            "valutaTo": "",
            "orderBy": ["column": "t.id", "orderType": "DESC"],
            "page": 1,
            "pageSize": pageSize
        ]
    }

    // MARK: - Wire format

    /// Every money field arrives as a string (`"31.85"`, `"-1.50"`) so that no
    /// cent is lost to a binary float on the way.
    private struct OverviewPayload: Decodable {
        struct Threshold: Decodable { var minimumBalance: String? }
        var balance: String?
        var totalBalance: String?
        var lowBalanceThreshold: Threshold?
    }

    private struct TransactionsPayload: Decodable {
        struct Entry: Decodable {
            var id: Int
            var datetime: Date
            var description: String
            var value: String

            var model: MensaTransaction? {
                guard let amount = Decimal(string: value) else { return nil }
                return MensaTransaction(id: id, date: datetime, text: description, amount: amount)
            }
        }
        var data: [Entry] = []
    }

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
