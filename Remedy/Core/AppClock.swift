//
//  AppClock.swift
//  Remedy
//
//  stores the date for the app so the demo can fake it
//

import Foundation

enum AppClock {

    private static let launchedAt = Date()

    // real time or the demo time
    static func now() -> Date {
        guard let minute = LaunchOptions.demoMinute else { return Date() }
        let todayMidnight = DayMath.calendar.startOfDay(for: launchedAt)
        let demoStart = todayMidnight.addingTimeInterval(TimeInterval(minute * 60))
        let secondsSinceLaunch = Date().timeIntervalSince(launchedAt)
        return demoStart.addingTimeInterval(secondsSinceLaunch)
    }
}
