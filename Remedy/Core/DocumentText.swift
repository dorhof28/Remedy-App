//
//  DocumentText.swift
//  Remedy
//
//  turns paragraphs lists and tables from a scan into the plain text the rest of the app reads
//

import Foundation

// one block of a page in reading order
nonisolated enum DocumentBlock: Equatable {
    case paragraph(String)
    case list([String])         // each item with its marker if it has one
    case table([[String]])      // rows of cells
}

// joins the blocks read from a document into one plain text
nonisolated enum DocumentText {

    // blocks joined with a blank line between them
    static func format(_ blocks: [DocumentBlock]) -> String {
        var parts: [String] = []
        for block in blocks {
            let text: String
            switch block {
            case .paragraph(let words):
                text = words.split(separator: "\n", omittingEmptySubsequences: true)
                    .map { bulleted(String($0)) }
                    .joined(separator: "\n")
            case .list(let items):
                text = items.map { listItem($0) }.filter { !$0.isEmpty }.joined(separator: "\n")
            case .table(let rows):
                text = rows.map { row in
                    row.map { clean($0) }.joined(separator: "   ").trimmingCharacters(in: .whitespaces)
                }.filter { !$0.isEmpty }.joined(separator: "\n")
            }
            if !text.isEmpty { parts.append(text) }
        }
        return parts.joined(separator: "\n\n")
    }

    // one line with inner line breaks turned into spaces
    static func clean(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    // numbered items keep their number the rest get a bullet
    static func listItem(_ raw: String) -> String {
        let text = clean(raw)
        guard !text.isEmpty else { return "" }
        let numbered = text.range(of: #"^\(?[0-9]{1,2}[.)]\s"#, options: .regularExpression) != nil
        return numbered ? text : bulleted(text)
    }

    // turns the many bullet shapes on paper into one
    static func bulleted(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for bullet in ["\u{2022}", "\u{25CF}", "\u{25AA}", "\u{25A0}", "\u{25E6}", "\u{25CB}", "\u{00B7}", "\u{F0B7}", "-", "*", ">", "o"]
        where trimmed.hasPrefix(bullet + " ") {
            return "\u{2022} " + trimmed.dropFirst(bullet.count + 1).trimmingCharacters(in: .whitespaces)
        }
        for box in ["\u{2610}", "\u{25A1}", "[ ]", "[]"] where trimmed.hasPrefix(box) {
            return "\u{2610} " + trimmed.dropFirst(box.count).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}
