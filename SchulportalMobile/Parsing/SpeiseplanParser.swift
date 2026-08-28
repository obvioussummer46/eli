import Foundation
import SwiftSoup

/// Scrapes `speiseplan.php`.
///
/// The page is the useful one on the whole site: a single server-rendered
/// request carries the week's menus, which of them is already ordered, *and*
/// the balance in the sidebar. The markup we rely on:
///
/// ```
/// span.username                                   who is logged in
/// span#guthaben                                   the balance, "31,85"
/// select[name=week] > option[value=2026_36]       the week pager
/// div.tab-pane.day#day-MO[name=2026-08-31]        one school day
///   input.hiddenmenuefield[name=menue_MO_0]       the ordered menu id, "" if none
///   div.panel.menue[rel=1429]                     one dish
///     h3.panel-title / .badge / p / p small       name, price, text, allergens
///     [data-content]                              the allergens spelled out
///     .disabled                                   past the ordering deadline
/// ```
enum SpeiseplanParser {
    struct Result: Equatable {
        var account = MensaAccount()
        var week = MenuWeek()
    }

    static func parse(html: String) throws -> Result {
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            throw MensaError.parsing("Der Speiseplan")
        }

        var result = Result()
        result.account = account(in: document)
        result.week = week(in: document)

        if result.week.days.isEmpty && result.account.username.isEmpty {
            throw MensaError.parsing("Der Speiseplan")
        }
        return result
    }

    // MARK: - Sidebar

    private static func account(in document: Document) -> MensaAccount {
        var account = MensaAccount()
        account.username = HTMLText.inline(document.firstMatch("span.username"))
        if let raw = document.firstMatch("#guthaben") {
            let text = HTMLText.inline(raw)
            if !text.isEmpty {
                account.balanceText = text
                account.balance = decimal(fromGerman: text)
            }
        }
        return account
    }

    // MARK: - Week

    private static func week(in document: Document) -> MenuWeek {
        var week = MenuWeek()

        var sawSelectedWeek = false
        for option in document.allMatches("select[name=week] option") {
            guard let key = option.attribute("value") else { continue }
            let label = HTMLText.inline(option)
            week.availableWeeks.append(WeekOption(key: key, label: label))
            // `selected` marks the week actually on screen. Falling back to the
            // first option keeps a plan that lost the attribute under *some*
            // heading rather than under none.
            if option.hasAttr("selected") || (!sawSelectedWeek && week.key.isEmpty) {
                week.key = key
                week.label = label
                sawSelectedWeek = sawSelectedWeek || option.hasAttr("selected")
            }
        }

        for pane in document.allMatches("div.tab-pane.day") {
            guard let day = day(pane) else { continue }
            week.days.append(day)
        }
        return week
    }

    private static func day(_ pane: Element) -> MenuDay? {
        // `id` is "day-MO"; the pane's `name` carries the ISO date.
        guard let rawID = pane.attribute("id"), rawID.hasPrefix("day-") else { return nil }
        let key = String(rawID.dropFirst("day-".count))

        var day = MenuDay(id: key, date: nil, isLocked: false, orderedOptionID: nil, options: [])
        if let iso = pane.attribute("name") { day.date = isoDay.date(from: iso) }

        // The hidden field is what the site would submit, so it — not the
        // `active` class — is the authority on what is ordered.
        if let hidden = pane.firstMatch("input.hiddenmenuefield"),
           let value = hidden.attribute("value"), value != "0" {
            day.orderedOptionID = value
        }

        for panel in pane.allMatches("div.panel.menue") {
            guard let option = option(panel) else { continue }
            day.options.append(option)
        }

        // Every panel of a closed day carries `disabled`; treat the day as
        // locked only when there is something that could have been ordered.
        let panels = pane.allMatches("div.panel.menue")
        day.isLocked = !panels.isEmpty && panels.allSatisfy { $0.hasClass("disabled") }

        return day
    }

    private static func option(_ panel: Element) -> MenuOption? {
        guard let id = panel.attribute("rel") else { return nil }
        let title = HTMLText.inline(panel.firstMatch(".panel-title"))
        guard !title.isEmpty else { return nil }

        let allergenCodes = HTMLText.inline(panel.firstMatch(".panel-body p small"))

        // The description is the body paragraph minus the allergen line, which
        // sits inside it as a `<small>`. Read the codes first, then drop the
        // element: nothing downstream looks at this panel's paragraph again.
        var text = ""
        if let paragraph = panel.firstMatch(".panel-body p") {
            paragraph.allMatches("small").forEach { try? $0.remove() }
            text = brSeparatedLines(paragraph)
        }

        return MenuOption(id: id,
                          title: title,
                          text: text,
                          priceText: HTMLText.inline(panel.firstMatch(".badge")),
                          allergenCodes: allergenCodes,
                          allergenText: panel.attribute("data-content") ?? "",
                          isCertified: panel.hasClass("colorflag-dge"))
    }

    // MARK: - Helpers

    /// Text where `<br>` — and only `<br>` — starts a new line.
    ///
    /// `HTMLText.multiline` also honours the newlines in the source, which is
    /// right for the Schulportal but wrong here: the caterer writes
    /// `Gericht<br>\nBeilage<br>\n<br>\nDessert`, so counting both turns every
    /// single break into a blank line and the deliberate blank line before
    /// "Dessert" stops meaning anything. Here the tags decide and the source
    /// whitespace is ignored.
    private static func brSeparatedLines(_ element: Element) -> String {
        var out = ""
        appendText(element.getChildNodes(), into: &out)
        let lines = out.components(separatedBy: "\n").map {
            $0.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        var result: [String] = []
        for line in lines {
            if line.isEmpty, result.last?.isEmpty ?? true { continue }
            result.append(line)
        }
        while result.last?.isEmpty == true { result.removeLast() }
        return result.joined(separator: "\n")
    }

    private static func appendText(_ nodes: [Node], into out: inout String) {
        for node in nodes {
            if let text = node as? TextNode {
                out += text.getWholeText()
                    .replacingOccurrences(of: "\u{00a0}", with: " ")
                    .replacingOccurrences(of: "[\n\r\t]+", with: " ", options: .regularExpression)
            } else if let child = node as? Element {
                if child.tagName().lowercased() == "br" {
                    out += "\n"
                } else {
                    appendText(child.getChildNodes(), into: &out)
                }
            }
        }
    }

    /// The pane's `name` attribute, e.g. `2026-08-31`.
    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = GermanDate.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "31,85" / "1.234,50 €" -> 1234.50
    static func decimal(fromGerman raw: String) -> Decimal? {
        let cleaned = raw
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }
}
