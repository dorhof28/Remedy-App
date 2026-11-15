//
//  AppClock.swift
//  Remedy
//
//  stores the date for the app so the demo can fake it
//

import Foundation

// the only source of now, so demo mode can move the clock for every screen at once
enum AppClock {

    private static let launchedAt = Date()

    // real time or the demo time
    static func now() -> Date {
        // the Demo mode steppers in Settings move today by whole days
        let shift = LaunchOptions.demoDayShift
        guard let minute = LaunchOptions.demoMinute else { return LaunchOptions.shifted(Date(), byDays: shift) }
        let todayMidnight = DayMath.calendar.startOfDay(for: launchedAt)
        let demoStart = todayMidnight.addingTimeInterval(TimeInterval(minute * 60))
        let secondsSinceLaunch = Date().timeIntervalSince(launchedAt)
        return LaunchOptions.shifted(demoStart.addingTimeInterval(secondsSinceLaunch), byDays: shift)
    }
}
