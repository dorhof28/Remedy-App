//
//  LaunchOptions.swift
//  Remedy
//
//  demo settings from the xcode scheme
//

import Foundation

enum LaunchOptions {

    // use the fake sample patient
    static var usesSamplePlan: Bool {
        UserDefaults.standard.bool(forKey: "demoSamplePlan")
    }

    // true = start with no plan so the Welcome screen shows
    static var startsEmpty: Bool {
        UserDefaults.standard.bool(forKey: "demoWelcome")
    }

    // true = use the fake AI answer even if Apple's AI is available
    static var usesFakeAI: Bool {
        UserDefaults.standard.bool(forKey: "demoFakeAI")
    }

    // true in either demo mode
    static var isDemo: Bool { usesSamplePlan || startsEmpty }

    // which day of the plan today is for the sample patient
    static var demoDay: Int {
        guard UserDefaults.standard.object(forKey: "demoDay") != nil else { return -9 }
        return UserDefaults.standard.integer(forKey: "demoDay")
    }

    static var demoMinute: Int? {
        guard let text = UserDefaults.standard.string(forKey: "demoTime") else { return nil }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }
}
