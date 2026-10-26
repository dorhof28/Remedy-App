//
//  Redactor.swift
//  Remedy
//
//  removes personal info from page text with fixed rules and name finding
//

import Foundation

// cleaned text and how much was removed
struct RedactedPage {
    let text: String
    let removedCount: Int       // how many things were blacked out
    var hidden: [String] = []   // the words we hid so the page picture can hide them too
}

enum Redactor {

    static let mark = "\u{2588}\u{2588}\u{2588}"     // ███

    // labels whose value is personal
    static let personalLabels = [
        "patient name", "patient", "pt name", "name", "legal name", "preferred name", "mrn", "medical record",
        "dob", "date of birth", "birth date", "address", "home address", "insurance", "member id", "policy",
        "account", "acct", "ssn", "guarantor", "emergency contact", "contact name", "spouse", "guardian",
        "home phone", "cell phone", "mobile", "email", "e-mail", "patient id", "csn", "fin", "visit id",
    ]

    // labels whose value is a name so we hide those words everywhere
    static let nameLabels: Set<String> = [
        "patient name", "patient", "pt name", "name", "legal name", "preferred name",
        "guarantor", "emergency contact", "contact name", "spouse", "guardian",
    ]

    // labels that often have no colon like DOB 01/02/1960
    static let bareLabels = ["dob", "mrn", "csn", "fin", "acct", "mrn #", "account #"]

    // removes personal info from one page
    // names nil uses the names saved in the scan screen
    static func redact(_ page: String, names: [String]? = nil) -> RedactedPage {
        var hidden: [String] = []
        var names: [String] = []
        var removed = 0
        var lines: [String] = []

        for line in page.components(separatedBy: .newlines) {
            var result = line

            for label in personalLabels {
                let escaped = NSRegularExpression.escapedPattern(for: label)
                let pattern = "(?i)(^\\s*|\\s{2,}|\\|\\s*)(\(escaped)\\s*[:#]\\s*)([^:|]+?)(?=\\s{2,}|\\s*\\||\\s+[A-Za-z]+\\s*[:#]|$)"
                let found = hide(pattern, group: 3, in: &result)
                if nameLabels.contains(label) { names += found }
                hidden += found
            }
            for label in bareLabels {
                let escaped = NSRegularExpression.escapedPattern(for: label)
                hidden += hide("(?i)\\b\(escaped)\\s+([0-9][0-9/\\-]{4,})", group: 1, in: &result)
            }

            // email
            hidden += hide("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", group: 0, in: &result)
            // street address like 12 Oak Hill Road
            hidden += hide("\\b\\d{1,6}\\s+(?:[A-Z][a-z]+\\s){1,3}(?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Drive|Boulevard|Blvd|Court|Ct|Way|Place|Pl|Terrace|Circle|Cir)\\b\\.?",
                           group: 0, in: &result)
            // mr smith and dear john
            let titled = hide("\\b(?:Mr|Mrs|Ms|Miss|Mx)\\.?\\s+([A-Z][A-Za-z'\\-]+(?:\\s+[A-Z][A-Za-z'\\-]+)?)", group: 1, in: &result)
            let dear = hide("^\\s*Dear\\s+([A-Z][A-Za-z'\\-]+(?:\\s+[A-Z][A-Za-z'\\-]+)*)", group: 1, in: &result)
            names += titled + dear
            hidden += titled + dear
            // long numbers that aren't phone numbers
            hidden += hide("(?<![\\d(-])\\d{6,}(?![\\d)-])", group: 0, in: &result)

            lines.append(result)
        }

        var text = lines.joined(separator: "\n")

        // names the patient typed in even if the camera misread them
        let (typed, typedFound) = PatientNames.hide(in: text, names: names ?? PatientNames.saved)
        text = typed
        hidden += typedFound

        // names the tagger finds that aren't doctors
        names += NameFinder.patientNames(in: text)
        let (spread, words) = hideNameWords(names, in: text)
        text = spread
        hidden += words

        removed = text.components(separatedBy: mark).count - 1
        return RedactedPage(text: text, removedCount: removed, hidden: unique(hidden))
    }

    // hides every word of these names everywhere on the page
    // so smith john and mr smith all go once one is found
    static func hideNameWords(_ names: [String], in text: String) -> (String, [String]) {
        let words = unique(names.flatMap { name in
            name.split { !$0.isLetter && $0 != "'" && $0 != "-" }.map(String.init)
        }).filter { $0.count >= 3 && !MedicalWords.isProtected($0) }

        var result = text
        for word in words {
            let capital = word.prefix(1).uppercased() + word.dropFirst().lowercased()
            let forms = [capital, word.uppercased()].map { NSRegularExpression.escapedPattern(for: $0) }
            let pattern = "(?<![A-Za-z])(?:\(forms.joined(separator: "|")))(?![A-Za-z])"
            _ = hide(pattern, group: 0, in: &result)
        }
        return (result, words)
    }

    // hides words found before again in new text like the ai's cleaner copy
    static func hideAgain(_ hidden: [String], in text: String) -> String {
        var result = text
        for item in hidden.sorted(by: { $0.count > $1.count }) where item.count >= 3 {
            result = result.replacingOccurrences(of: item, with: mark, options: .caseInsensitive)
        }
        return hideNameWords(hidden.filter { $0.contains(where: \.isLetter) }, in: redact(result).text).0
    }

    // MARK: - Helpers

    // replaces one group of each match with the mark and returns what it hid
    @discardableResult
    private static func hide(_ pattern: String, group: Int, in text: inout String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var found: [String] = []
        for match in matches.reversed() {
            guard let range = Range(match.range(at: group), in: text) else { continue }
            let value = text[range].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty, !value.contains(mark), value.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            found.append(value)
            text.replaceSubrange(range, with: mark)
        }
        return found
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0.lowercased()).inserted }
    }
}
