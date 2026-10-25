//
//  WidgetSnapshot.swift
//  Remedy
//
//  what the widget shows shared through the app group
//

import Foundation

// one state of the widget from date on
nonisolated struct WidgetEntryData: Codable, Hashable {
    let date: Date
    let eyebrow: String         // "Due now · 2:00 PM"
    let title: String           // "Acetaminophen"
    let detail: String          // "2 tablets"
    let symbol: String          // SF Symbol name
}

nonisolated enum WidgetSnapshot {

    // must match the App Group added to both targets in Signing & Capabilities
    static let appGroup = "group.com.dorronhoffman.Remedy"
    private static let key = "widgetSnapshot"

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
}
