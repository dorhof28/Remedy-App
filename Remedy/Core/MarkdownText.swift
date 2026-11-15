//
//  MarkdownText.swift
//  Remedy
//
//  turns the markdown or html an ai reader writes into the same plain text the camera reader gives
//  bullets become one bullet shape, numbers stay, tables keep their cells, nothing else is changed
//

import Foundation

// turns markdown or html some readers write back into plain text
nonisolated enum MarkdownText {

    static func plain(_ markdown: String) -> String {
        var text = markdown
        // html tables and breaks some readers write
        for (pattern, swap) in [("(?i)<br\\s*/?>", " "), ("(?i)</t[dh]>", "   "), ("(?i)</tr>", "\n"), ("(?i)</?(table|thead|tbody|tr|td|th|p|div|span)[^>]*>", "")] {
            text = text.replacingOccurrences(of: pattern, with: swap, options: .regularExpression)
        }
        var lines: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.replacingOccurrences(of: "\t", with: "    ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { continue }
            // a table row like | a | b | and its --- line
            if trimmed.hasPrefix("|") {
                let cells = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.allSatisfy({ $0.isEmpty || $0.allSatisfy { "-: ".contains($0) } }) { continue }
                lines.append(cells.filter { !$0.isEmpty }.map(unstyled).joined(separator: "   "))
                continue
            }
            // headings lose their hashes
            if let match = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                lines.append(unstyled(String(trimmed[match.upperBound...])))
                continue
            }
            // bullets keep how deep they are
            let indent = line.prefix { $0 == " " }.count
            line = String(line.dropFirst(indent))
            if let match = line.range(of: "^[-*+]\\s+(\\[[ xX]\\]\\s*)?", options: .regularExpression) {
                let box = line[match].contains("[") ? "\u{2610} " : "\u{2022} "
                let depth = min(indent / 2, 3)
                lines.append(String(repeating: "  ", count: depth) + box + unstyled(String(line[match.upperBound...])))
                continue
            }
            lines.append(String(repeating: "  ", count: min(indent / 2, 3)) + DocumentText.bulleted(unstyled(line)))
        }
        // at most one blank line in a row
        var result: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if result.last?.isEmpty == false { result.append("") }
            } else {
                result.append(line)
            }
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // bold and italic marks off, the words stay
    static func unstyled(_ text: String) -> String {
        var result = text
        for pattern in ["\\*\\*(.+?)\\*\\*", "__(.+?)__", "(?<![\\w*])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![\\w*])"] {
            result = result.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
