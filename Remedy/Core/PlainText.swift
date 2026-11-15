//
//  PlainText.swift
//  Remedy
//
//  small helpers for readable text
//

import Foundation

// small text helpers used everywhere words are built
nonisolated enum PlainText {

    
    // a b and c
    static func list(_ items: [String]) -> String {
        if items.isEmpty { return "" }
        if items.count == 1 { return items[0] }
        let allButLast = items.dropLast().joined(separator: ", ")
        return allButLast + " and " + (items.last ?? "")
    }

    // 1 tablet or 2 tablets
    static func count(_ number: Int, _ word: String) -> String {
        number == 1 ? "1 \(word)" : "\(number) \(word)s"
    }

    // which paper and page
    // the line over a quote, "From your paper, page 3"
    static func source(paper: PaperKind, page: Int?) -> String {
        guard let page = page else { return "From your paper" }
        return "From your paper, page \(page)"
    }

    // lowercases the first letter
    static func lowerFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).lowercased() + String(text.dropFirst())
    }

    // capitalises the first letter
    static func upperFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    // html note to plain lines, block tags become line breaks and entities are decoded
    static func fromHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<br\\s*/?>|</(p|div|li|tr|h[1-6])>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // &amp; last so "&amp;lt;" stays "&lt;"
        let entities = [("&nbsp;", " "), ("&ndash;", "\u{2013}"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&amp;", "&")]
        for (code, letter) in entities { text = text.replacingOccurrences(of: code, with: letter) }
        let lines = text.components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
