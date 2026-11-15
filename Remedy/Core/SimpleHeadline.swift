//
//  SimpleHeadline.swift
//  Remedy
//
//  the one line the simple home leads with, picked by plain rules
//

import Foundation

// one thing coming up for the patient
nonisolated struct SimpleAgendaItem: Equatable {
    enum Kind: Equatable { case dose, visit, stop }
    // only doses today are due or late
    enum State: Equatable { case dueNow, late, upcoming }

    let kind: Kind
    let daysFromToday: Int
    let minute: Int?
    let title: String
    var state: State = .upcoming

    // a visit or a medicine stopping can change the plan so it counts as important
    var isImportant: Bool { kind == .visit || kind == .stop }
}

// picks the one thing the simple home screen shows first
nonisolated enum SimpleHeadline {

    // order: due or late now, visit today, important tomorrow, next dose today, tomorrow's first, next later
    static func pick(_ items: [SimpleAgendaItem]) -> SimpleAgendaItem? {
        let upcoming = items.filter { $0.daysFromToday >= 0 }.sorted(by: earlier)
        let today = upcoming.filter { $0.daysFromToday == 0 }
        let tomorrow = upcoming.filter { $0.daysFromToday == 1 }

        if let due = today.first(where: { $0.kind == .dose && $0.state == .dueNow }) { return due }
        if let late = today.first(where: { $0.kind == .dose && $0.state == .late }) { return late }
        if let visit = today.first(where: { $0.kind == .visit }) { return visit }
        if let important = tomorrow.first(where: { $0.isImportant }) { return important }
        if let dose = today.first(where: { $0.kind == .dose && $0.state == .upcoming }) { return dose }
        if let first = tomorrow.first { return first }
        return upcoming.first { $0.daysFromToday > 1 }
    }

    // the sentence, like "Tomorrow at 8:00 AM: take Amlodipine"
    static func line(_ items: [SimpleAgendaItem], now: Date, calendar: Calendar = DayMath.calendar) -> String? {
        guard let item = pick(items) else { return nil }
        // doses at the same time read as one list
        let same = items.filter {
            $0.kind == item.kind && $0.daysFromToday == item.daysFromToday && $0.minute == item.minute && $0.state == item.state
        }
        var unique: [String] = []
        for title in same.map(\.title) where !unique.contains(title) { unique.append(title) }
        let names = PlainText.list(unique)
        let what: String
        switch item.kind {
        case .dose: what = "take \(names)"
        case .stop: what = "stop \(names)"
        case .visit: what = names
        }
        if item.daysFromToday == 0, item.kind == .dose {
            if item.state == .dueNow { return "Now: \(what)" }
            if item.state == .late, let minute = item.minute { return "Was due at \(DayMath.timeText(minute)): \(what)" }
        }
        let when = SimpleWording.when(daysFromToday: item.daysFromToday, minute: item.minute, now: now, calendar: calendar)
        return "\(when): \(what)"
    }

    // sooner day first, then sooner time
    private static func earlier(_ a: SimpleAgendaItem, _ b: SimpleAgendaItem) -> Bool {
        if a.daysFromToday != b.daysFromToday { return a.daysFromToday < b.daysFromToday }
        return (a.minute ?? -1) < (b.minute ?? -1)
    }
}
