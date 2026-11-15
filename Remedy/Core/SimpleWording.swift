//
//  SimpleWording.swift
//  Remedy
//
//  plain calendar words for the simple look, never day counters
//

import Foundation

// plain words for days and times on simple screens
nonisolated enum SimpleWording {

    // today tomorrow friday or nov 23
    static func dayWord(daysFromToday days: Int, now: Date, calendar: Calendar = DayMath.calendar) -> String {
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        if days == -1 { return "yesterday" }
        let start = calendar.startOfDay(for: now)
        guard let date = calendar.date(byAdding: .day, value: days, to: start) else { return "" }
        // a weekday name only reads right inside the next week
        let formatter = (days >= 2 && days <= 6) ? weekdayFormatter : monthDayFormatter
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private static let weekdayFormatter = formatter("EEEE")
    private static let monthDayFormatter = formatter("MMM d")

    // a fixed us english formatter so words never change with the phone's language
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = format
        return formatter
    }

    // the same for a real date
    static func dayWord(for date: Date, now: Date, calendar: Calendar = DayMath.calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        return dayWord(daysFromToday: days, now: now, calendar: calendar)
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    // "Tomorrow at 9:00 AM" / "Friday"
    static func when(daysFromToday days: Int, minute: Int?, now: Date, calendar: Calendar = DayMath.calendar) -> String {
        let word = capitalized(dayWord(daysFromToday: days, now: now, calendar: calendar))
        guard let minute else { return word }
        return "\(word) at \(DayMath.timeText(minute))"
    }

    // takes counters out of shared wording, "Stop Oct 28 · 1 day before surgery" becomes "Stop Oct 28"
    static func plain(_ text: String) -> String {
        let patterns = [
            #"(?:\s*[·,]\s*)?\b(?:the day (?:before|after)|\d+ days? (?:before|after)) surgery\b\.?"#,
            #"(?:\s*[·,]\s*)?\b(?:in \d+ days?|\d+ days? ago)\b\.?"#,
            #"\bDay \d+ of recovery\b"#
        ]
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        let junk = CharacterSet(charactersIn: " ·,")
        return result.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: junk)
    }
}
