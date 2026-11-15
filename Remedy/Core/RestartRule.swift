//
//  RestartRule.swift
//  Remedy
//
//  restarting a stopped medicine (screen 36): the patient says who said OK and when, remedy never restarts on its own
//

import Foundation

// when a stopped medicine may start again and who can say so
nonisolated enum RestartRule {

    // who can say a stopped medicine is OK again
    static let whoOptions = ["Surgeon\u{2019}s office", "Another doctor", "Pharmacist"]

    // the stop ends the day before the restart day
    static func stopEndDay(restartDay: Int) -> Int { restartDay - 1 }

    // "Restarted, said OK by surgeon's office, Mon, Nov 23"
    static func note(who: String, dateText: String) -> String {
        "Restarted, said OK by \(PlainText.lowerFirst(who)), \(dateText)"
    }
}
