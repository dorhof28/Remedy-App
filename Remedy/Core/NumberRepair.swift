//
//  NumberRepair.swift
//  Remedy
//
//  fixes clear misreads inside dates and doses like "1O mg" or "1] 1/18/2026"
//  every fix is told to the patient so a changed number is never hidden
//

import Foundation

// fixes letters the camera reads in place of digits, like 5O0 mg for 500 mg
nonisolated enum NumberRepair {

    // one fix, shown to the patient
    struct Change: Equatable, Sendable {
        let from: String
        let to: String
    }

    // the text with clear misreads fixed and what was changed
    static func repair(_ text: String) -> (text: String, changes: [Change]) {
        var result = text
        var changes: [Change] = []
        for rule in [strayMarkInDate, lettersInDate, lettersInDose] {
            let pass = rule(result)
            result = pass.text
            changes += pass.changes
        }
        return (result, changes)
    }

    // plain lines for the patient, at most three
    static func notes(_ changes: [Change]) -> [String] {
        var seen: Set<String> = []
        return changes.filter { seen.insert($0.from).inserted }.prefix(3).map {
            "Remedy read \u{201C}\($0.from)\u{201D} as \u{201C}\($0.to)\u{201D}. Check it on the paper."
        }
    }

    // MARK: - Rules

    // "1] 1/18/2026" is 11/18/2026 when that is a real date
    private static func strayMarkInDate(_ text: String) -> (text: String, changes: [Change]) {
        replace(in: text, pattern: #"\b\d[\]\[|!]\s?\d{1,2}/\d{1,2}/\d{2,4}\b"#) { found in
            let fixed = found.filter { $0.isNumber || $0 == "/" }
            return isDate(fixed) ? fixed : nil
        }
    }

    // "1O/2l/2026" is 10/21/2026, letters that look like digits inside a date
    private static func lettersInDate(_ text: String) -> (text: String, changes: [Change]) {
        replace(in: text, pattern: #"\b[0-9OoIl]{1,2}/[0-9OoIl]{1,2}/[0-9OoIl]{2,4}\b"#) { found in
            guard found.contains(where: isLookAlike) else { return nil }
            let fixed = digits(found)
            return isDate(fixed) ? fixed : nil
        }
    }

    // "1O mg" is 10 mg and "5OO mg" is 500 mg, only right before a dose unit and with a real digit in it
    private static func lettersInDose(_ text: String) -> (text: String, changes: [Change]) {
        replace(in: text, pattern: #"\b[0-9OoIl]*[0-9][0-9OoIl]*(?=\s?(?:mg|mcg|ml|mL|units?|tablets?)\b)"#) { found in
            found.contains(where: isLookAlike) ? digits(found) : nil
        }
    }

    // MARK: - Helpers

    private static func isLookAlike(_ character: Character) -> Bool { "OoIl".contains(character) }

    // O becomes 0 and I or l becomes 1
    private static func digits(_ text: String) -> String {
        String(text.map { character -> Character in
            switch character {
            case "O", "o": return "0"
            case "I", "l": return "1"
            default: return character
            }
        })
    }

    // month 1 to 12 and day 1 to 31
    static func isDate(_ text: String) -> Bool {
        let parts = text.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        return (1...12).contains(parts[0]) && (1...31).contains(parts[1])
    }

    // runs the fix on every match of the pattern and lists what changed
    private static func replace(in text: String, pattern: String,
                                with fix: (String) -> String?) -> (text: String, changes: [Change]) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (text, []) }
        let ns = text as NSString
        var result = text
        var changes: [Change] = []
        // from the end so earlier ranges stay right
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let found = ns.substring(with: match.range)
            guard let fixed = fix(found), fixed != found else { continue }
            result = (result as NSString).replacingCharacters(in: match.range, with: fixed)
            changes.insert(Change(from: found, to: fixed), at: 0)
        }
        return (result, changes)
    }
}
