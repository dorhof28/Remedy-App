//
//  SurgeryDateFinder.swift
//  Remedy
//
//  finds the surgery date from labels like date of surgery without the ai
//

import Foundation

enum SurgeryDateFinder {

    // phrases that say the date next to them is the surgery
    static let labels = [
        "date of surgery", "surgery date", "date of procedure", "procedure date", "date of operation",
        "operation date", "surgery is scheduled", "surgery scheduled", "scheduled for surgery",
        "your surgery is on", "surgery is on", "your procedure is on", "procedure is scheduled",
        "day of surgery:", "surgery on",
    ]

    // a line with these is about another day
    static let otherDayWords = [
        "visit", "consult", "appointment", "printed", "pre-op", "preop", "pre op", "pre-admission",
        "preadmission", "testing", "encounter", "follow", "post-op", "postop", "date of service", "dob", "birth",
    ]

    // any written date like november 3 2026 or 11/3/2026
    static let datePattern = "(?i)\\b(?:(?:mon|tues|wednes|thurs|fri|satur|sun)day,?\\s+)?(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\\.?\\s+\\d{1,2},?\\s+\\d{4}\\b|\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{4}\\b"

    // the labelled date or nil
    static func find(in pages: [String]) -> Date? {
        let lines = pages.flatMap { $0.components(separatedBy: .newlines) }
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard let label = labels.first(where: { lower.contains($0) }),
                  !otherDayWords.contains(where: { lower.contains($0) }) else { continue }

            // the date after the label on the same line
            if let start = line.range(of: label, options: .caseInsensitive)?.upperBound {
                let after = String(line[start...])
                if let date = firstDate(in: after) { return date }
            }
            // or under it like in a table
            for next in lines.dropFirst(index + 1).prefix(2) {
                if let date = firstDate(in: next) { return date }
            }
        }
        return nil
    }

    // every written date in a piece of text
    static func dates(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: datePattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    private static func firstDate(in text: String) -> Date? {
        dates(in: text).lazy.compactMap { ExplicitDateParser.parse(date: $0.replacingOccurrences(of: ".", with: "")) }.first
    }
}
