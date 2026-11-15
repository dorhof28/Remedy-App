//
//  Redactor.swift
//  Remedy
//
//  hides personal info the phone ai found plus what the fixed rules find
//

import Foundation

// one personal detail the phone ai found copied as written
nonisolated struct PersonalSpan: Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable { case name, address, phone, dob, id, email, other }
    let kind: Kind
    let text: String
}

// one piece of a page for the check screen
struct RedactedPiece: Equatable {
    let text: String        // the real words even when hidden
    let isHidden: Bool
    let isWord: Bool        // a word can be tapped to hide it
}

// a page and the parts of it that are hidden
struct RedactedPage {
    let original: String
    var usedAI = false      // false means only the fixed rules checked this page
    private(set) var hiddenRanges: [Range<String.Index>] = []     // sorted and never overlapping

    init(original: String, usedAI: Bool = false) {
        self.original = original
        self.usedAI = usedAI
    }

    // the page as it is sent with each hidden part as ███
    var text: String {
        pieces.map { $0.isHidden ? Redactor.mark : $0.text }.joined()
    }

    var removedCount: Int { hiddenRanges.count }

    // the hidden words so the page picture can hide them too
    var hidden: [String] {
        var seen: Set<String> = []
        return hiddenRanges.map { String(original[$0]) }.filter { seen.insert($0.lowercased()).inserted }
    }

    // hidden parts and words in between
    var pieces: [RedactedPiece] {
        var result: [RedactedPiece] = []
        var cursor = original.startIndex
        for range in hiddenRanges {
            result += Redactor.words(in: original[cursor..<range.lowerBound])
            result.append(RedactedPiece(text: String(original[range]), isHidden: true, isWord: false))
            cursor = range.upperBound
        }
        return result + Redactor.words(in: original[cursor...])
    }

    // hides every copy of this text on the page
    // a known medicine word on a medicine line stays unless the person picked it
    mutating func hide(_ item: String, keepingMedicines: Bool = true) {
        let keeps = keepingMedicines && MedicalWords.medicines.contains(Redactor.plain(item))
        let found = Redactor.ranges(of: item, in: original).filter { !(keeps && Redactor.isOnMedicineLine($0, in: original)) }
        guard !found.isEmpty else { return }
        var merged: [Range<String.Index>] = []
        for range in (hiddenRanges + found).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        hiddenRanges = merged
    }

    // shows every copy of this hidden text on the page
    mutating func show(_ text: String) {
        hiddenRanges.removeAll { original[$0].lowercased() == text.lowercased() }
    }
}

// hides names and id numbers from page text before it leaves the phone
enum Redactor {

    nonisolated static let mark = "\u{2588}\u{2588}\u{2588}"     // ███

    // labels whose value is personal
    static let personalLabels = [
        "patient name", "patient", "pt name", "name", "legal name", "preferred name", "mrn", "medical record",
        "dob", "date of birth", "birth date", "address", "home address", "insurance", "member id", "policy",
        "account", "acct", "ssn", "guarantor", "emergency contact", "contact name", "spouse", "guardian",
        "home phone", "cell phone", "cell", "mobile", "email", "e-mail", "patient id", "csn", "fin", "visit id",
        "patient signature", "eid", "ceid", "epic id", "mychart id", "hospital id", "har", "encounter id",
    ]

    // labels whose value is a name so we hide those words everywhere
    static let nameLabels: Set<String> = [
        "patient name", "patient", "pt name", "name", "legal name", "preferred name",
        "guarantor", "emergency contact", "contact name", "spouse", "guardian", "patient signature",
    ]

    // labels that often have no colon like MRN NG-0047719
    static let bareLabels = ["dob", "mrn", "csn", "fin", "acct", "mrn #", "account #", "eid", "ceid"]

    // labels that mean a line is the patient header like SMITH, JOHN A  MRN 123
    static let idLabels = ["mrn", "dob", "date of birth", "patient id", "medical record", "csn", "fin", "acct"]

    // hides personal info on one page
    // found is what the phone ai flagged and names nil uses the names saved in the scan screen
    static func redact(_ page: String, names: [String]? = nil, found: [PersonalSpan] = [], usedAI: Bool = false) -> RedactedPage {
        let rules = ruleFinds(in: page, typed: names ?? PatientNames.saved)
        let aiNames = found.filter { $0.kind == .name }.map(\.text)
        var result = RedactedPage(original: page, usedAI: usedAI)
        // hide if either the ai or the rules flagged it
        for item in rules.items + found.map(\.text) + nameWords(rules.names + aiNames) {
            result.hide(item)
        }
        return result
    }

    // what the fixed rules flag and which of those are names
    static func ruleFinds(in page: String, typed: [String]) -> (items: [String], names: [String]) {
        var items: [String] = []
        var names: [String] = []
        var lines: [String] = []

        for line in page.components(separatedBy: .newlines) {
            var result = line

            for label in personalLabels {
                let escaped = NSRegularExpression.escapedPattern(for: label)
                let pattern = "(?i)(^\\s*|\\s{2,}|\\|\\s*)(\(escaped)\\s*[:#]\\s*)([^:|]+?)(?=\\s{2,}|\\s*\\||\\s+[A-Za-z]+\\s*[:#]|$)"
                let found = hide(pattern, group: 3, in: &result)
                if nameLabels.contains(label) { names += found }
                items += found
            }
            for label in bareLabels {
                let escaped = NSRegularExpression.escapedPattern(for: label)
                items += hide("(?i)\\b\(escaped)\\s*[:#]?\\s*([A-Z0-9][A-Z0-9/\\-]{3,})", group: 1, in: &result).filter { $0.contains(where: \.isNumber) }
            }

            // a name with no label at the start of a header line
            if let header = headerName(in: line), result.contains(header) {
                result = result.replacingOccurrences(of: header, with: mark)
                names.append(header)
                items.append(header)
            }

            // email
            items += hide("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", group: 0, in: &result)
            // the patient's own phone like Cell 555.0142 or Home ph 555 - 0143
            items += hide("(?i)\\b(?:cell|mobile|home)(?:\\s*ph(?:one)?)?\\s*[:#]?\\s*(\\(?\\d{3}\\)?[\\s.\\-]*\\d{3,4}(?:[\\s.\\-]*\\d{4})?)", group: 1, in: &result)
            // street address like 12 Oak Hill Road
            items += hide("\\b\\d{1,6}\\s+(?:[A-Z][a-z]+\\s){1,3}(?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Drive|Boulevard|Blvd|Court|Ct|Way|Place|Pl|Terrace|Circle|Cir)\\b\\.?",
                          group: 0, in: &result)
            // apt 3B and springfield, MA 01105
            items += hide("\\b(?:Apt|Apartment|Unit)\\.?\\s*#?\\s*[A-Za-z0-9-]*\\d[A-Za-z0-9-]*", group: 0, in: &result)
            items += hide("\\b(?:[A-Z][a-z'.-]+\\s){0,2}[A-Z][a-z'.-]+,\\s*[A-Z]{2}\\s+\\d{5}(?:-\\d{4})?\\b", group: 0, in: &result)
            // born on the eighth of march 1961
            items += hide("(?i)\\bborn\\s+(?:on\\s+)?(.{3,40}?\\b(?:19|20)\\d{2})\\b", group: 1, in: &result)
            // mr smith and dear john
            let titled = hide("\\b(?:Mr|Mrs|Ms|Miss|Mx)\\.?\\s+([A-Z][A-Za-z'\\-]+(?:\\s+[A-Z][A-Za-z'\\-]+)?)", group: 1, in: &result)
            let dear = hide("^\\s*Dear\\s+([A-Z][A-Za-z'\\-]+(?:\\s+[A-Z][A-Za-z'\\-]+)*)", group: 1, in: &result)
            names += titled + dear
            items += titled + dear
            // long numbers that aren't phone numbers
            items += hide("(?<![\\d(-])\\d{6,}(?![\\d)-])", group: 0, in: &result)

            lines.append(result)
        }

        // names the patient typed in even if the camera misread them
        items += PatientNames.hide(in: lines.joined(separator: "\n"), names: typed).1
        return (items, names)
    }

    // the name before MRN or DOB on a header line like Walter J. Pietrangeli MRN: 123
    static func headerName(in line: String) -> String? {
        let labels = idLabels.compactMap {
            line.range(of: "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b\\s*[:#]?\\s*\\d", options: [.regularExpression, .caseInsensitive])
        }
        guard let first = labels.min(by: { $0.lowerBound < $1.lowerBound }) else { return nil }
        let before = line[..<first.lowerBound].trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "(,")))
        let pattern = "^[A-Z][A-Za-z'\\-]*\\.?,?(?:\\s+[A-Z][A-Za-z'\\-]*\\.?,?){1,3}$"
        guard before.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let words = before.split { !$0.isLetter && $0 != "'" && $0 != "-" }.map(String.init)
        guard !words.contains(where: MedicalWords.isProtected) else { return nil }
        return before
    }

    // each word of these names so smith john and mr smith all go once one is found
    // with a capital so only Hope or HOPE is hidden never hope
    // medicines are left to the medicine line check in hide
    static func nameWords(_ names: [String]) -> [String] {
        names.flatMap { name in
            name.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "-" }.map(String.init)
        }.filter { word in
            let lower = plain(word)
            return word.count >= 3 && word.contains(where: \.isLetter)
                && !MedicalWords.notNames.contains(lower) && !MedicalWords.careTitles.contains(lower)
        }.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    // every copy of this text as whole words
    // any spaces or commas between its words and a capital stays a capital so hope never hides in we hope
    static func ranges(of item: String, in text: String) -> [Range<String.Index>] {
        let parts = item.split { $0.isWhitespace || $0 == "," }.map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard let first = item.first(where: { !$0.isWhitespace }), let last = item.last(where: { !$0.isWhitespace }),
              item.filter({ $0.isLetter || $0.isNumber }).count >= 2 else { return [] }
        let before = first.isLetter ? "(?<!\\p{L})" : first.isNumber ? "(?<!\\p{N})" : ""
        let after = last.isLetter ? "(?!\\p{L})" : last.isNumber ? "(?!\\p{N})" : ""
        let pattern = before + parts.joined(separator: "[\\s,]+") + after
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            if first.isUppercase, let start = text[range].first, !start.isUppercase { return nil }
            return range
        }
    }

    // the line around a range has a dose or says stop take or hold
    static func isOnMedicineLine(_ range: Range<String.Index>, in text: String) -> Bool {
        let start = text[..<range.lowerBound].lastIndex(where: \.isNewline).map { text.index(after: $0) } ?? text.startIndex
        let end = text[range.upperBound...].firstIndex(where: \.isNewline) ?? text.endIndex
        return MedicalWords.isMedicineLine(String(text[start..<end]))
    }

    // lower case without the dots and commas around it
    static func plain(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
    }

    // words and the gaps between them so each word can be tapped
    // a word keeps inner dots and dashes like rosa.quill@example.com or 555-0142 but not the full stop after it
    static func words(in text: Substring) -> [RedactedPiece] {
        let pattern = "[\\p{L}\\p{N}]+(?:['\u{2019}./@_-][\\p{L}\\p{N}]+)*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let whole = String(text)
        var result: [RedactedPiece] = []
        var cursor = whole.startIndex
        for match in regex.matches(in: whole, range: NSRange(whole.startIndex..., in: whole)) {
            guard let range = Range(match.range, in: whole) else { continue }
            if cursor < range.lowerBound { result.append(RedactedPiece(text: String(whole[cursor..<range.lowerBound]), isHidden: false, isWord: false)) }
            result.append(RedactedPiece(text: String(whole[range]), isHidden: false, isWord: true))
            cursor = range.upperBound
        }
        if cursor < whole.endIndex { result.append(RedactedPiece(text: String(whole[cursor...]), isHidden: false, isWord: false)) }
        return result
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
}
