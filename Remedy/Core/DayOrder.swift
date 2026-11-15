//
//  DayOrder.swift
//  Remedy
//
//  where a daily goal sits in the day, a goal without a time never leads and is never late
//

import Foundation

// the order rows show in on a day
nonisolated enum DayOrder {

    // the row groups of a day, soonest group first
    enum Lane: Int, Comparable {
        case urgent = 0     // due now or missed medicines
        case early = 1      // stop today, fasting, check-in
        case timed = 2      // anything with a clock time, goals with a time too
        case anyTime = 3    // to-dos
        case goals = 4      // goals with no time
        case asNeeded = 5

        static func < (a: Lane, b: Lane) -> Bool { a.rawValue < b.rawValue }
    }

    // how a goal reads right now, never missed or overdue
    enum GoalWhen: Equatable {
        case anyTime        // no time on it
        case later          // its time is still ahead
        case now            // its time has come
    }

    // the one clock time written on a goal, nil when it has none or says two
    static func goalMinute(title: String, detail: String, quote: String) -> Int? {
        for text in [title, detail, quote] {
            if let minute = LastGivenParser.minute(in: text) { return minute }
        }
        return nil
    }

    // the goal's time on a day
    static func goalDate(minute: Int, on day: Date, calendar: Calendar = DayMath.calendar) -> Date? {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }

    // a goal with a time is now once that time has passed, otherwise later
    static func goalWhen(minute: Int?, now: Date, calendar: Calendar = DayMath.calendar) -> GoalWhen {
        guard let minute, let date = goalDate(minute: minute, on: now, calendar: calendar) else { return .anyTime }
        return now >= date ? .now : .later
    }

}
