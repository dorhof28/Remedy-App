//
//  LaunchOptions.swift
//  Remedy
//
//  demo settings from the xcode scheme
//

import Foundation

// debug only launch arguments for demos, screenshots and tests
enum LaunchOptions {

    // use the fake sample patient
    static var usesSamplePlan: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "demoSamplePlan")
        #else
        return false
        #endif
    }

    // a demo plan from the demo mode list like surgeryIn10Days, loaded as the plan
    static var demoScenario: DemoScenario? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoScenario").flatMap(DemoScenario.init(rawValue:))
        #else
        return nil
        #endif
    }

    // true = start with no plan so the Welcome screen shows
    static var startsEmpty: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "demoWelcome")
        #else
        return false
        #endif
    }

    // true = use the fake AI answer even if Apple's AI is available
    static var usesFakeAI: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "demoFakeAI")
        #else
        return false
        #endif
    }

    // true = the lock calendar and reminder steps never show, so screenshots and tours are not blocked
    // a fake ai run skips them too unless -skipPermissionPrompts NO is passed
    static var skipsPermissionPrompts: Bool {
        #if DEBUG
        if UserDefaults.standard.object(forKey: "skipPermissionPrompts") != nil {
            return UserDefaults.standard.bool(forKey: "skipPermissionPrompts")
        }
        return usesFakeAI
        #else
        return false
        #endif
    }

    // DEBUG ONLY opens one first-run screen straight away for screenshots: setup, reader, restore or demo
    static var demoScreen: String? {
        #if DEBUG
        return startsEmpty ? UserDefaults.standard.string(forKey: "demoScreen") : nil
        #else
        return nil
        #endif
    }

    // true in either demo mode
    static var isDemo: Bool { usesSamplePlan || startsEmpty || demoScenario != nil }

    // same as isDemo plus the Demo mode switch in Settings
    // RootView also checks the plan's isSample so a real scan never shows the banner
    static var isSampleData: Bool { usesSamplePlan || startsEmpty || demoScenario != nil || isDemoMode }

    // MARK: - Demo mode switch in Settings (works in every build, off until the user turns it on)

    static let demoModeKey = "demoModeOn"
    static let demoShiftKey = "demoDayShift"
    static let demoLoadedKey = "demoLoadedName"
    // how far the fake today can move either way
    static let maxDayShift = 365

    static var isDemoMode: Bool { UserDefaults.standard.bool(forKey: demoModeKey) }

    // demo mode only: added papers get their expected answer instead of going to the ai
    static let demoExpectedAnswersKey = "demoExpectedAnswers"
    static var usesExpectedAnswers: Bool { isDemoMode && UserDefaults.standard.bool(forKey: demoExpectedAnswersKey) }

    // days the fake today is away from the real one, always 0 with demo mode off
    static var demoDayShift: Int {
        isDemoMode ? clampedShift(UserDefaults.standard.integer(forKey: demoShiftKey)) : 0
    }

    // keeps the demo clock within a year either way
    static func clampedShift(_ days: Int) -> Int {
        min(max(days, -maxDayShift), maxDayShift)
    }

    // a date moved by whole calendar days
    static func shifted(_ date: Date, byDays days: Int) -> Date {
        days == 0 ? date : (DayMath.calendar.date(byAdding: .day, value: days, to: date) ?? date)
    }

    // which day of the plan today is for the sample patient
    static var demoDay: Int {
        #if DEBUG
        guard UserDefaults.standard.object(forKey: "demoDay") != nil else { return -9 }
        return UserDefaults.standard.integer(forKey: "demoDay")
        #else
        return -9
        #endif
    }

    static var demoMinute: Int? {
        #if DEBUG
        guard let text = UserDefaults.standard.string(forKey: "demoTime") else { return nil }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
        #else
        return nil
        #endif
    }
}
