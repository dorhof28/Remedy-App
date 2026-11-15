//
//  DayPhraseParser.swift
//  Remedy
//
//  turns words like 7 days before surgery into a day number
//

import Foundation

// turns phrases like for 2 weeks or day 3 to 5 into plan days
nonisolated enum DayPhraseParser {

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "twenty-one": 21, "thirty": 30,
        "a": 1,
    ]

    private static let pattern = "\\b(\\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|twenty-one|thirty|a)(?:\\s*\\(\\d+\\))?(?:\\s*(?:-|to|or)\\s*(\\d+|one|two|three|four|five|six|seven|eight|nine|ten|fourteen))?\\s*(days?|weeks?)\\s*(?:\\(\\d+\\)\\s*)?(before|prior to|prior|ahead of|in advance of|after|following|post)"

    // surgery day is 0 the day before is -1 nil if no phrase
    static func day(in text: String) -> Int? {
        let lower = text.lowercased()

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            func part(_ index: Int) -> String? {
                Range(match.range(at: index), in: lower).map { String(lower[$0]) }
            }
            let first = number(part(1)) ?? 0
            let second = number(part(2)) ?? first
            let unit = (part(3) ?? "").hasPrefix("week") ? 7 : 1
            let isBefore = !["after", "following", "post"].contains(part(4) ?? "")
            // 7 to 10 days before means stop at 10 to be safe
            return isBefore ? -max(first, second) * unit : first * unit
        }

        // 24 hours before is the day before 48 is two days
        if let regex = try? NSRegularExpression(pattern: "\\b(\\d+)\\s*(?:hours?|hrs?)\\s*(?:before|prior)"),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower), let hours = Int(lower[range]), hours > 0 {
            return -Int((Double(hours) / 24).rounded(.up))
        }

        let dayBefore = ["night before", "night prior", "evening before", "evening prior", "day before surgery",
                         "day before your surgery", "day prior to surgery", "day prior to your surgery"]
        if dayBefore.contains(where: { lower.contains($0) }) { return -1 }
        if lower.contains("day of surgery") || lower.contains("morning of surgery") || lower.contains("day of your surgery")
            || lower.contains("morning of your surgery") { return 0 }
        if lower.contains("day after surgery") || lower.contains("day after your surgery") { return 1 }
        return nil
    }

    // a digit or a number word up to twelve
    private static func number(_ text: String?) -> Int? {
        guard let text else { return nil }
        return Int(text) ?? numberWords[text]
    }
}
