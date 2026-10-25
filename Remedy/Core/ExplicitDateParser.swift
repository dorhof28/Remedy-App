//
//  ExplicitDateParser.swift
//  Remedy
//
//  turns a full written date into a real date - from nikhil
//

import Foundation

enum ExplicitDateParser {

    private static let dateFormats = [
        "MMMM d, yyyy",
        "MMMM d yyyy",
        "MMM d, yyyy",
        "MMM d yyyy",
        "MMM. d, yyyy",
        "EEEE, MMMM d, yyyy",
        "EEE, MMM d, yyyy",
        "M/d/yyyy",
        "M-d-yyyy",
        "yyyy-MM-dd",
    ]

    private static let timeFormats = [
        "h:mm a",
        "h:mma",
        "h a",
        "ha",
        "HH:mm",
    ]

    // the date or nil
    static func parse(date dateText: String, time timeText: String? = nil, calendar: Calendar = .current) -> Date? {
        let dateText = dateText.trimmingCharacters(in: .whitespacesAndNewlines)

        // must have a 4-digit year or we'd be guessing
        guard dateText.range(of: #"\b\d{4}\b"#, options: .regularExpression) != nil,
              let day = firstMatch(dateText, formats: dateFormats, calendar: calendar) else {
            return nil
        }

        let timeText = (timeText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !timeText.isEmpty,
              let time = firstMatch(timeText.uppercased(), formats: timeFormats, calendar: calendar) else {
            return calendar.startOfDay(for: day)
        }

        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day)
    }

    // tries each format in turn
    private static func firstMatch(_ text: String, formats: [String], calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
