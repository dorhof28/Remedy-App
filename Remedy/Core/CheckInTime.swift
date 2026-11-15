//
//  CheckInTime.swift
//  Remedy
//
//  the daily check-in time: which days get a reminder and when to ask for the time
//

import Foundation

// when the daily check-in reminder fires and which days get one
nonisolated enum CheckInTime {

    static let defaultMinute = 9 * 60       // 9 AM
    static let firstDay = 1                 // check-ins start the day after surgery
    static let lastDay = 30                 // the recovery period the reminders cover
    static let daysAhead = 7                // how far ahead notifications are set
    static let promptGapDays = 2            // one more ask this many days after a Not now
    static let maxPrompts = 2               // never more than twice

    // minutes after midnight kept in a sane day
    static func clamped(_ minute: Int) -> Int { min(max(minute, 0), 24 * 60 - 1) }

    // "9:00 AM"
    static func text(minute: Int) -> String {
        let clean = clamped(minute)
        let hour = clean / 60
        let shown = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", shown, clean % 60, hour < 12 ? "AM" : "PM")
    }

    // plan days that get a reminder, skipping days already checked in
    static func reminderDays(today: Int, checkedIn: Set<Int>) -> [Int] {
        let start = max(today, firstDay)
        let end = min(today + daysAhead, lastDay)
        guard start <= end else { return [] }
        return (start...end).filter { !checkedIn.contains($0) }
    }

    // the wall clock time on a day, right even on days the clocks change
    static func date(minute: Int, onDayOf day: Date) -> Date {
        let clean = clamped(minute)
        return DayMath.calendar.date(bySettingHour: clean / 60, minute: clean % 60, second: 0, of: day)
            ?? DayMath.calendar.startOfDay(for: day).addingTimeInterval(TimeInterval(clean * 60))
    }

    // after the time has passed a check-in is just something to do when you can
    static func hasPassed(minute: Int, now: Date) -> Bool {
        let parts = DayMath.calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) >= clamped(minute)
    }

    // the one time prompt: only with no time set, from surgery day on, and once more after a Not now
    static func shouldPrompt(minute: Int?, today: Int, dismissals: Int, lastDismissedDay: Int?) -> Bool {
        guard minute == nil, today >= 0, today <= lastDay, dismissals < maxPrompts else { return false }
        if dismissals == 0 { return true }
        return today >= (lastDismissedDay ?? today) + promptGapDays
    }
}
