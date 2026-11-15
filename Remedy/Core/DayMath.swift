//
//  DayMath.swift
//  Remedy
//
//  turns +/- day numbers into real dates and other date helpers
//

import Foundation

// plan days are counted from surgery: day 0 is surgery, negative is before
nonisolated enum DayMath {

    static var calendar: Calendar { Calendar.current }

   
    // plan day to a real date
    static func date(forDay day: Int, from surgeryDate: Date) -> Date {
        let start = calendar.startOfDay(for: surgeryDate)
        return calendar.date(byAdding: .day, value: day, to: start) ?? start
    }

    // plan day and minute to a real date
    static func date(forDay day: Int, minute: Int, from surgeryDate: Date) -> Date {
        let midnight = date(forDay: day, from: surgeryDate)
        return midnight.addingTimeInterval(TimeInterval(minute * 60))
    }

    // real date to a plan day
    static func dayOffset(of date: Date, from surgeryDate: Date) -> Int {
        let start = calendar.startOfDay(for: surgeryDate)
        let target = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.day], from: start, to: target)
        return parts.day ?? 0
    }

    // minutes since midnight
    static func minuteOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // thu oct 22
    static func shortDate(_ date: Date) -> String {
        shortFormatter.string(from: date)
    }

    // thursday october 22
    static func longDate(_ date: Date) -> String {
        longFormatter.string(from: date)
    }

    // short date for a plan day
    static func shortDate(forDay day: Int, from surgeryDate: Date) -> String {
        shortDate(date(forDay: day, from: surgeryDate))
    }

    // long date for a plan day
    static func longDate(forDay day: Int, from surgeryDate: Date) -> String {
        longDate(date(forDay: day, from: surgeryDate))
    }

    // weekday for the day picker
    static func weekdayLetters(forDay day: Int, from surgeryDate: Date) -> String {
        weekdayFormatter.string(from: date(forDay: day, from: surgeryDate))
    }

    // day of the month for the day picker
    static func dayNumber(forDay day: Int, from surgeryDate: Date) -> String {
        let parts = calendar.dateComponents([.day], from: date(forDay: day, from: surgeryDate))
        return String(parts.day ?? 0)
    }

    // date to relative words like tomorrow
    static func relative(daysFromToday: Int) -> String {
        switch daysFromToday {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        default:
            if daysFromToday > 0 { return "in \(daysFromToday) days" }
            return "\(-daysFromToday) days ago"
        }
    }

    // 4 days before surgery etc
    static func surgeryWords(forDay day: Int) -> String {
        if day == 0 { return "surgery day" }
        if day == -1 { return "the day before surgery" }
        if day == 1 { return "the day after surgery" }
        if day < 0 { return "\(-day) days before surgery" }
        return "\(day) days after surgery"
    }

    // minutes to 2:00 PM
    static func timeText(_ minuteOfDay: Int) -> String {
        let minutes = minuteOfDay % 60
        var hour = (minuteOfDay / 60) % 24
        let suffix = hour >= 12 ? "PM" : "AM"
        hour = hour % 12 == 0 ? 12 : hour % 12
        let twoDigits = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hour):\(twoDigits) \(suffix)"
    }

    // minutes to 2 PM
    static func shortTimeText(_ minuteOfDay: Int) -> String {
        if minuteOfDay % 60 != 0 { return timeText(minuteOfDay) }
        var hour = (minuteOfDay / 60) % 24
        let suffix = hour >= 12 ? "PM" : "AM"
        hour = hour % 12 == 0 ? 12 : hour % 12
        return "\(hour) \(suffix)"
    }

    // time of a date
    static func timeText(of date: Date) -> String {
        timeText(minuteOfDay(date))
    }

    // minutes to 1 hr 20 min
    static func duration(minutes total: Int) -> String {
        let hours = total / 60
        let minutes = total % 60
        if hours == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(minutes) min"
    }
    
    // digits to a readable phone number
    static func phoneText(_ digits: String) -> String {
        guard digits.count == 10 else { return digits }
        let characters = Array(digits)
        let area = String(characters[0..<3])
        let middle = String(characters[3..<6])
        let last = String(characters[6..<10])
        return "(\(area)) \(middle)-\(last)"
    }

    // convert phonenumebr
    static func phoneURL(_ digits: String) -> URL? {
        URL(string: "tel:" + digits)
    }

    // link address for directions
    static func mapsURL(_ address: String) -> URL? {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?q=" + encoded)
    }

    // format everythign
    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()
}
