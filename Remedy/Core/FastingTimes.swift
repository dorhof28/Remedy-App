//
//  FastingTimes.swift
//  Remedy
//
//  turns "clear liquids until 2 hours before arrival" into clock times
//

import Foundation

// when to stop food and clear liquids, worked out from the paper's words and the arrival time
nonisolated enum FastingTimes {

    // "2 hours before" or "two hours before" gives 2
    static func hoursBefore(in text: String) -> Int? {
        let lower = text.lowercased()
        guard lower.contains("before") else { return nil }
        let words = ["one": 1, "two": 2, "three": 3, "four": 4, "six": 6, "eight": 8]
        let parts = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for (index, part) in parts.enumerated() where index + 1 < parts.count && parts[index + 1].hasPrefix("hour") {
            if let number = Int(part), number > 0, number <= 24 { return number }
            if let number = words[part] { return number }
        }
        return nil
    }

    // the last moment for clear liquids
    static func clearLiquidsEnd(arrival: Date, hoursBefore: Int) -> Date {
        arrival.addingTimeInterval(-TimeInterval(hoursBefore * 3600))
    }

    // finds the clear liquids rule in the texts and works out its time
    static func clearLiquidsEnd(arrival: Date?, texts: [String]) -> Date? {
        guard let arrival else { return nil }
        for text in texts where text.lowercased().contains("clear liquid") {
            if let hours = hoursBefore(in: text) { return clearLiquidsEnd(arrival: arrival, hoursBefore: hours) }
        }
        return nil
    }

    // "nothing to eat after midnight" gives the midnight that starts surgery day
    static func foodStop(surgeryDate: Date, texts: [String]) -> Date? {
        let found = texts.contains {
            let lower = $0.lowercased()
            return lower.contains("midnight") && (lower.contains("eat") || lower.contains("food"))
        }
        return found ? DayMath.calendar.startOfDay(for: surgeryDate) : nil
    }

    // "Arrive at 6:00 AM" gives that time on surgery day
    static func arrival(fromTexts texts: [String], surgeryDate: Date) -> Date? {
        for text in texts where text.lowercased().contains("arriv") {
            if let minute = clockMinute(in: text) {
                return DayMath.date(forDay: 0, minute: minute, from: surgeryDate)
            }
        }
        return nil
    }

    // the same clock time moved onto surgery day
    static func onSurgeryDay(_ time: Date, surgeryDate: Date) -> Date {
        DayMath.date(forDay: 0, minute: DayMath.minuteOfDay(time), from: surgeryDate)
    }

    // minutes after midnight for the first "6:00 AM" or "6 pm" in the text
    static func clockMinute(in text: String) -> Int? {
        let pattern = #"(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        func group(_ index: Int) -> String? {
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
        guard let hourText = group(1), var hour = Int(hourText), (1...12).contains(hour) else { return nil }
        let minute = group(2).flatMap { Int($0) } ?? 0
        guard minute < 60 else { return nil }
        let isPM = group(3)?.lowercased() == "p"
        if hour == 12 { hour = 0 }
        if isPM { hour += 12 }
        return hour * 60 + minute
    }
}
