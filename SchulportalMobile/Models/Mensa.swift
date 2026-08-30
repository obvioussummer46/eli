import Foundation

/// The mensa side of the app: `menuebestellung.de`, a completely separate
/// service from the Schulportal with its own account, its own session and its
/// own money.
///
/// Everything here is read-only. Choosing a menu costs real money and the app
/// deliberately does not do it — the website's own "Menüauswahl speichern" is
/// still the only way to order.

/// One selectable dish on one day.
struct MenuOption: Codable, Equatable, Identifiable, Hashable {
    /// The site's menu id (`rel` on the panel). Stable across days: the same
    /// "Pastabar" carries the same id all week, so it is only unique *within* a
    /// day.
    var id: String
    var title: String
    /// The multi-line description, dessert line included.
    var text: String
    /// As printed, e.g. `3,00 €` — kept verbatim so a changed price or a free
    /// menu is never silently rounded into something else.
    var priceText: String
    /// The short codes under the description, e.g. `1, GL, LA`.
    var allergenCodes: String
    /// The same codes spelled out, from the panel's popover.
    var allergenText: String
    /// Carries the DGE quality seal.
    var isCertified: Bool
}

/// One school day of the plan.
struct MenuDay: Codable, Equatable, Identifiable {
    /// `MO` … `FR`, the site's own key.
    var id: String
    var date: Date?
    /// The site has closed this day for changes — usually because it is in the
    /// past or past the ordering deadline.
    var isLocked: Bool
    /// Which option is ordered, from the day's hidden field. `nil` when nothing
    /// is ordered.
    var orderedOptionID: String?
    var options: [MenuOption]

    var orderedOption: MenuOption? {
        guard let orderedOptionID else { return nil }
        return options.first { $0.id == orderedOptionID }
    }

    var weekdayLabel: String {
        guard let date else { return id }
        return GermanDate.shortWeekdayDayMonth.string(from: date)
    }
}

/// One calendar week, as the site paginates it.
struct MenuWeek: Codable, Equatable {
    /// `2026_36` — year and ISO week, the value of the `week` query parameter.
    var key: String = ""
    /// `KW 36 (31.08. - 06.09.)`
    var label: String = ""
    var days: [MenuDay] = []
    /// Every week the site offers, in the order it lists them.
    var availableWeeks: [WeekOption] = []

    var isEmpty: Bool { days.allSatisfy(\.options.isEmpty) }
}

struct WeekOption: Codable, Equatable, Hashable, Identifiable {
    var id: String { key }
    var key: String
    var label: String
}

/// Who is logged in and what is left on the card.
struct MensaAccount: Codable, Equatable {
    var username: String = ""
    /// Verbatim, e.g. `31,85` — see `MenuOption.priceText`.
    var balanceText: String?
    /// The same figure as a number, when the site gave us one to parse.
    var balance: Decimal?

    var balanceDisplay: String {
        guard let balanceText, !balanceText.isEmpty else { return "—" }
        return "\(balanceText) €"
    }

    /// Below the threshold the site itself warns about.
    func isLow(threshold: Decimal = 15) -> Bool {
        guard let balance else { return false }
        return balance < threshold
    }
}

/// One line of the account statement: a kiosk purchase, a top-up, or a menu
/// pick-up.
struct MensaTransaction: Codable, Equatable, Identifiable {
    /// The site's own id where it sends one, else a stable digest of the row —
    /// it is a `String` because the back end answers with `12` on one route and
    /// `"12"` on the next, and neither is worth losing a booking over.
    var id: String
    var date: Date
    var text: String
    var amount: Decimal

    /// Pick-up confirmations come through as 0,00 € bookings — they document a
    /// meal rather than move money.
    var isBooking: Bool { amount != 0 }
}

/// What the statement page reports in one go.
struct MensaStatement: Codable, Equatable {
    var balance: Decimal?
    var balanceText: String?
    var lowBalanceThreshold: Decimal?
    var transactions: [MensaTransaction] = []
}
