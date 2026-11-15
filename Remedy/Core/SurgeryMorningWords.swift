//
//  SurgeryMorningWords.swift
//  Remedy
//
//  the lock screen lines for surgery morning (screen 29), from the times the papers give
//

import Foundation

// the words on today's card on surgery morning
nonisolated enum SurgeryMorningWords {

    static let title = "Surgery today"

    // "Arrive by 6:30 AM", remedy has no travel time so it never makes up a leave by time
    static func headline(arrival: Date?) -> String? {
        arrival.map { "Arrive by \(DayMath.timeText(of: $0))" }
    }

    // "Nothing to eat. Clear liquids until 4:30 AM." then nothing to drink once it passes
    static func detail(liquidsEnd: Date?, hasFoodRule: Bool, now: Date) -> String? {
        var parts: [String] = []
        if let end = liquidsEnd {
            if now >= end {
                parts.append(hasFoodRule ? "Nothing to eat or drink." : "Nothing to drink.")
            } else {
                if hasFoodRule { parts.append("Nothing to eat.") }
                parts.append("Clear liquids until \(DayMath.timeText(of: end)).")
            }
        } else if hasFoodRule {
            parts.append("Nothing to eat.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
