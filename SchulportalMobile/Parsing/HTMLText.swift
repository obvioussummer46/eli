import Foundation
import SwiftSoup

/// Turning portal markup into text that still has its line breaks.
///
/// `Element.text()` collapses every run of whitespace, which destroys the
/// multi-line homework blocks teachers write. So we walk the node tree instead
/// and keep `<br>` and block boundaries as real newlines.
enum HTMLText {
    static func multiline(_ element: Element?) -> String {
        guard let element else { return "" }
        var out = ""
        appendNodes(element.getChildNodes(), into: &out)
        return cleanUp(out)
    }

    private static let blockTags: Set<String> = ["p", "div", "li", "tr", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "blockquote"]

    private static func appendNodes(_ nodes: [Node], into out: inout String) {
        for node in nodes {
            if let text = node as? TextNode {
                out += text.getWholeText()
            } else if let element = node as? Element {
                let tag = element.tagName().lowercased()
                if tag == "br" {
                    out += "\n"
                    continue
                }
                if blockTags.contains(tag), !out.isEmpty, !out.hasSuffix("\n") { out += "\n" }
                appendNodes(element.getChildNodes(), into: &out)
                if blockTags.contains(tag), !out.hasSuffix("\n") { out += "\n" }
            }
        }
    }

    static func cleanUp(_ raw: String) -> String {
        let unified = raw
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = unified
            .components(separatedBy: "\n")
            .map { line in
                line.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }

        // Collapse runs of blank lines into a single one.
        var result: [String] = []
        for line in lines {
            if line.isEmpty, result.last?.isEmpty ?? true { continue }
            result.append(line)
        }
        while result.last?.isEmpty == true { result.removeLast() }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Single-line, whitespace-collapsed text — for titles and labels.
    static func inline(_ element: Element?) -> String {
        guard let element else { return "" }
        let raw = (try? element.text()) ?? ""
        return raw.replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Element {
    func firstMatch(_ query: String) -> Element? {
        (try? select(query))?.first()
    }

    func allMatches(_ query: String) -> [Element] {
        guard let elements = try? select(query) else { return [] }
        return elements.array()
    }

    func attribute(_ name: String) -> String? {
        guard let value = try? attr(name), !value.isEmpty else { return nil }
        return value
    }

    /// Direct children with one of the given tag names. SwiftSoup's selector
    /// engine does not reliably accept a leading `>` combinator, so structural
    /// walking is done through `children()` instead.
    func childElements(_ tags: Set<String>) -> [Element] {
        children().array().filter { tags.contains($0.tagName().lowercased()) }
    }
}
