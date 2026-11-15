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
    var nextEvent: WidgetLine? = nil    // next appointment, shown when no dose is coming
}

// what kind of top line the entry holds, read from the eyebrow the Today card wrote
nonisolated enum WidgetKind {
    case due, missed, next, allDone, other
}

nonisolated extension WidgetEntryData {

    var kind: WidgetKind {
        if eyebrow.hasPrefix("Due now") { return .due }
        if eyebrow.hasPrefix("Missed") { return .missed }
        if eyebrow.hasPrefix("Next") { return .next }
        if title == "All done for today" || title == "No set-time medicines today" { return .allDone }
        return .other
    }

    // the clock time inside the eyebrow like 2:00 PM
    var timeText: String? {
        let parts = eyebrow.components(separatedBy: " \u{00B7} ")
        return parts.count > 1 ? parts.last : nil
    }

    // one short line for the inline lock screen widget
    // next dose first then next event, stop-taking items are never the headline
    var inlineText: String {
        func joined(_ words: String, _ time: String?) -> String {
            time.map { "\(words) \($0)" } ?? words
        }
        switch kind {
        case .due: return joined("Take \(title)", timeText)
        case .missed: return joined("Missed: \(title)", timeText)
        case .next: return joined("Next: \(title)", timeText)
        case .allDone, .other:
            break
        }
        if let line = upNext?.first(where: { $0.symbol == "pills.fill" }) {
            return "Next: \(line.title) \(line.time)"
        }
        if let event = nextEvent { return "\(event.title) \(event.time)" }
        if title.hasPrefix("Today is your surgery") { return "Surgery day today" }
        if let line = upNext?.first(where: { $0.symbol != "nosign" && !$0.title.lowercased().hasPrefix("stop") }) {
            return "\(line.time): \(line.title)"
        }
        return kind == .allDone ? "Medicines done today" : "Open Remedy for today"
    }
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

// the snapshot saved in the app group for the widget to read
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
