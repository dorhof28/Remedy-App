//
//  Redactor.swift
//  Remedy
//
//  removes personal info from page text with fixed rules
//

import Foundation

// cleaned text and how much was removed
struct RedactedPage {
    let text: String
    let removedCount: Int       // how many things were blacked out
}

enum Redactor {

    static let mark = "\u{2588}\u{2588}\u{2588}"     // ███

    // labels whose value is personal
    static let personalLabels = [
        "patient name", "patient", "name", "mrn", "medical record", "dob", "date of birth",
        "birth date", "address", "insurance", "member id", "account", "acct", "ssn", "guarantor",
    ]

    // removes personal info from one page
    static func redact(_ page: String) -> RedactedPage {
        var removed = 0
        var lines: [String] = []

        for line in page.components(separatedBy: .newlines) {
            var result = line

            for label in personalLabels {
                let pattern = "(?i)(^\\s*|\\s{2,})(\(NSRegularExpression.escapedPattern(for: label))\\s*[:#]\\s*)([^:]+?)(?=\\s{2,}|\\s+[A-Za-z]+\\s*[:#]|$)"
                let (newText, count) = replace(pattern, in: result, with: "$1$2\(mark)")
                result = newText
                removed += count
            }

            // 2 long numbers that aren't phone numbers
            let (newText, count) = replace("(?<![\\d(-])\\d{6,}(?![\\d)-])", in: result, with: mark)
            result = newText
            removed += count

            lines.append(result)
        }
        return RedactedPage(text: lines.joined(separator: "\n"), removedCount: removed)
    }

    // MARK: - Helper

    // regex replace that also says how many matches it changed
    private static func replace(_ pattern: String, in text: String, with template: String) -> (String, Int) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (text, 0) }
        let range = NSRange(text.startIndex..., in: text)
        let count = regex.numberOfMatches(in: text, range: range)
        guard count > 0 else { return (text, 0) }
        return (regex.stringByReplacingMatches(in: text, range: range, withTemplate: template), count)
    }
}
