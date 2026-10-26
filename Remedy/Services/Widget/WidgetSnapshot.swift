//
//  WidgetSnapshot.swift
//  Remedy
//
//  what the widgets show shared through the app group
//

import Foundation

// one small line like the next dose
nonisolated struct WidgetLine: Codable, Hashable {
    let time: String            // "2:00 PM" or "Mon 3"
    let title: String           // "Acetaminophen"
    let symbol: String
}

// one state of the today widget from date on
nonisolated struct WidgetEntryData: Codable, Hashable {
    let date: Date
    let eyebrow: String         // "Due now · 2:00 PM"
    let title: String           // "Acetaminophen"
    let detail: String          // "2 tablets"
    let symbol: String          // SF Symbol name
    var dayText: String? = nil          // "Day 3 of recovery"
    var upNext: [WidgetLine]? = nil     // the next few things today
    var takenText: String? = nil        // "2 of 5 taken"
    var takenFraction: Double? = nil
}

// one key day for the journey widget
nonisolated struct WidgetStop: Codable, Hashable {
    let date: Date
    let month: String           // "NOV"
    let dayNumber: String       // "3"
    let weekday: String         // "Mon"
    let label: String           // "3 days before surgery"
    let title: String           // "Stop aspirin"
    let symbol: String
    let tone: String            // "stop" "info" "caution" "neutral"
    let isSurgery: Bool
}

// the whole journey for the widget
nonisolated struct WidgetJourney: Codable, Hashable {
    let surgeryDate: Date
    let procedure: String
    let stops: [WidgetStop]
}

nonisolated enum WidgetSnapshot {

    // must match the App Group added to both targets in Signing & Capabilities
    static let appGroup = "group.com.dorronhoffman.Remedy"
    private static let key = "widgetSnapshot"
    private static let journeyKey = "widgetJourney"

    private static var storage: UserDefaults? { UserDefaults(suiteName: appGroup) }

    // app writes the lines
    static func save(_ entries: [WidgetEntryData]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        storage?.set(data, forKey: key)
    }

    // widget reads the lines
    static func load() -> [WidgetEntryData] {
        guard let data = storage?.data(forKey: key),
              let entries = try? JSONDecoder().decode([WidgetEntryData].self, from: data) else { return [] }
        return entries
    }

    // app writes the journey nil clears it
    static func saveJourney(_ journey: WidgetJourney?) {
        guard let journey, let data = try? JSONEncoder().encode(journey) else {
            storage?.removeObject(forKey: journeyKey)
            return
        }
        storage?.set(data, forKey: journeyKey)
    }

    // widget reads the journey
    static func loadJourney() -> WidgetJourney? {
        guard let data = storage?.data(forKey: journeyKey) else { return nil }
        return try? JSONDecoder().decode(WidgetJourney.self, from: data)
    }
}
