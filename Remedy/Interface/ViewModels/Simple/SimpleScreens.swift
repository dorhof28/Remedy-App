//
//  SimpleScreens.swift
//  Remedy
//
//  words for the redesigned simple look: home (79), my day (80), medicines (81), one medicine (82), help (83)
//

import Foundation
import SwiftData

// MARK: - 79 Home

// the simple home screen: the one thing to do now and the tiles
struct SimpleHomeScreen {

    let base: TodayViewModel

    init(base: TodayViewModel) { self.base = base }

    let readAloud = "Read Aloud"
    let settingsButton = "Settings"
    let notNowButton = "Not Now"

    // "Thursday"
    var title: String {
        switch base.layout {
        case .noPlan, .needsSurgeryDate: return "Today"
        default: return base.now.formatted(.dateTime.weekday(.wide))
        }
    }

    // "Day 3 after surgery", "Surgery day", "Surgery in 4 days"
    var subtitle: String {
        switch base.layout {
        case .afterSurgery: return "Day \(base.day) after surgery"
        case .surgeryDay: return "Surgery day"
        case .beforeSurgery: return base.headerTitle
        case .noPlan, .needsSurgeryDate: return DayMath.longDate(base.now)
        }
    }

    // "Do now · 8:00 PM", "Missed · 6:00 AM", "Next · 10:00 PM"
    static func eyebrow(_ item: SimpleDayItem) -> String {
        let time = item.whenText.components(separatedBy: " \u{00B7} ").last ?? item.whenText
        switch item.state {
        case .now: return time.isEmpty ? "Do now" : "Do now \u{00B7} \(time)"
        case .anyTime: return "Do now"
        case .late: return "Missed \u{00B7} \(time)"
        case .later: return "Next \u{00B7} \(time)"
        case .done: return TodayViewModel.simpleAllDoneTitle
        }
    }

    // the big button in the patient's words, nil when there is nothing to press
    static func button(_ item: SimpleDayItem) -> String? {
        switch item.kind {
        case .dose: return item.buttonTitle == nil ? nil : "I Took It"
        case .asNeeded: return item.buttonTitle == nil ? nil : "I Took One"
        case .stop:
            guard item.buttonTitle != nil else { return nil }
            return item.title.contains(" and ") ? "I\u{2019}ve Put Them Away" : "I\u{2019}ve Put It Away"
        case .checkIn: return "Start Check-In"
        case .todo, .goal: return item.buttonTitle == nil ? nil : "Done"
        case .fillIn: return "Add It Now"
        case .visit, .surgery, .rule: return nil
        }
    }

    // one tile on the home screen
    struct Tile: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let route: SimpleRoute
        var isHelp: Bool { route == .help }
    }

    let tiles: [Tile] = [
        Tile(id: "day", title: "My Day", symbol: "list.bullet", route: .today),
        Tile(id: "medicines", title: "Medicines", symbol: "pills", route: .medicines),
        Tile(id: "ask", title: "Ask", symbol: "questionmark.bubble", route: .ask),
        Tile(id: "help", title: "Help", symbol: "phone.fill", route: .help)
    ]
}

// MARK: - 80 My Day

// the words on my day
enum SimpleMyDayWords {
    static let title = "My Day"
    static let before = "Before"
    static let next = "Next"
    static let pickDay = "Pick a Day"
    static let backToToday = "Back to Today"
    static let missedNote = "Missed one? Don\u{2019}t take an extra one to catch up."

    // just the time, "10:00 PM", or "Any time today"
    static func time(_ item: SimpleDayItem) -> String {
        item.whenText.components(separatedBy: " \u{00B7} ").last ?? item.whenText
    }

    // "2 of 5"
    static func position(_ index: Int, of count: Int) -> String {
        count == 0 ? "" : "\(index + 1) of \(count)"
    }

    // the first thing still to do, else the first one
    static func startIndex(_ items: [SimpleDayItem]) -> Int {
        items.firstIndex { $0.state == .now || $0.state == .late || $0.state == .anyTime }
            ?? items.firstIndex { $0.state == .later } ?? 0
    }

    // a dose card says so when a dose of the same medicine was missed today
    static func showsMissedNote(_ item: SimpleDayItem, in items: [SimpleDayItem]) -> Bool {
        guard item.kind == .dose, item.state != .done, let medicine = item.medicine else { return false }
        return items.contains { other in
            other.kind == .dose && other.state == .late && other.medicine?.persistentModelID == medicine.persistentModelID
        }
    }
}

// MARK: - 81 Medicines

// one card on simple medicines
struct SimpleMedicineCard: Identifiable {
    let id: String
    // nil for the one card of stopped medicines
    let medicine: MedicineInstruction?
    let title: String
    let status: String
    var tone: Tone = .neutral
    var isNow = false
}

// simple medicines: take now, as needed, and one card of what not to take
struct SimpleMedicinesScreen {

    let title = "Medicines"
    let dontTake = "Don\u{2019}t take"
    let emptyText = "Add your hospital papers to see your medicines."

    let cards: [SimpleMedicineCard]

    init(plan: CarePlan?, now: Date) {
        let screen = MedicinesViewModel(plan: plan, now: now)
        let day = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
        let slots = plan.map { DoseSchedule.slotsWithCheck(onDay: day, plan: $0, now: now) } ?? []
        var now_: [SimpleMedicineCard] = []
        var rest: [SimpleMedicineCard] = []

        for line in screen.groups[.everyDay] ?? [] {
            guard let medicine = line.medicine else { continue }
            let mine = slots.filter { $0.medicine.persistentModelID == medicine.persistentModelID }
            let name = TodayViewModel.shortName(medicine.name)
            if mine.contains(where: { $0.state == .due }) {
                now_.append(SimpleMedicineCard(id: line.id, medicine: medicine, title: name,
                                               status: "Take \(Self.count(medicine.amount)) now", tone: .info, isNow: true))
            } else if let missed = mine.last(where: { $0.state == .missed }) {
                // a missed dose is never made up, same as today
                now_.append(SimpleMedicineCard(id: line.id, medicine: medicine, title: name,
                                               status: "Missed \(Self.shortTime(missed.scheduledFor)). Don\u{2019}t take an extra one.",
                                               tone: .caution, isNow: true))
            } else if let next = mine.first(where: { $0.state == .upcoming }) {
                rest.append(SimpleMedicineCard(id: line.id, medicine: medicine, title: name,
                                               status: "Next at \(Self.shortTime(next.scheduledFor))"))
            } else {
                rest.append(SimpleMedicineCard(id: line.id, medicine: medicine, title: name,
                                               status: SimpleWording.plain(line.subtitle)))
            }
        }
        for line in screen.groups[.asNeeded] ?? [] {
            guard let medicine = line.medicine else { continue }
            let canTake = MedicineDetailViewModel(medicine: medicine, now: now).canLogAsNeeded
            let when = medicine.onlyIf.isEmpty ? "now" : "if \(Self.lowerFirst(medicine.onlyIf))"
            rest.append(SimpleMedicineCard(id: line.id, medicine: medicine, title: TodayViewModel.shortName(medicine.name),
                                           status: canTake ? "You can take \(Self.count(medicine.amount)) \(when)"
                                                           : SimpleWording.plain(line.subtitle),
                                           tone: canTake ? .good : .neutral))
        }
        let stopped = (screen.groups[.stopped] ?? []).compactMap(\.medicine)
        if !stopped.isEmpty {
            let names = TodayViewModel.uniqueNames(stopped.map { TodayViewModel.shortName($0.name) })
            rest.append(SimpleMedicineCard(id: "stopped", medicine: stopped.count == 1 ? stopped.first : nil,
                                           title: names.joined(separator: ", "), status: dontTake, tone: .stop))
        }
        cards = now_ + rest
    }

    // "1 tablet" is "1", words stay "1"
    static func count(_ amount: String) -> String {
        let first = amount.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty || Double(first) == nil ? "1" : first
    }

    // "10 PM", "10:30 PM"
    static func shortTime(_ date: Date) -> String {
        // always 12 hour like the rest of the app, never the phone's 19
        DayMath.shortTimeText(DayMath.minuteOfDay(date))
    }

    static func lowerFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }
}

// MARK: - 82 One medicine

// the words on simple medicine pages
enum SimpleMedicineWords {
    static let showPaper = "Show the Paper"
    static let more = "More About It"
    static let tookOne = "I Took One"

    // "You can take 1 now" when an only-if-needed dose is allowed
    static func eyebrow(_ medicine: MedicineInstruction, canTake: Bool, fallback: String) -> String {
        canTake ? "You can take \(SimpleMedicinesScreen.count(medicine.amount)) now" : fallback
    }

    // "Then wait 6 hours." then what is left today, the paper's sentence otherwise
    static func lines(_ medicine: MedicineInstruction, canTake: Bool, title: String, detail: String) -> [String] {
        guard canTake, let hours = medicine.minHoursBetween else { return [title, detail].filter { !$0.isEmpty } }
        let wait = hours == 1 ? "Then wait 1 hour." : "Then wait \(hours) hours."
        // the daily limit stays on screen, it is a safety rule
        return [wait, detail].filter { !$0.isEmpty }
    }

    // "Only if pain is very bad" for as-needed, the strength otherwise
    static func subtitle(_ medicine: MedicineInstruction, fallback: String) -> String {
        guard !medicine.onlyIf.isEmpty else { return fallback }
        return "Only if \(SimpleMedicinesScreen.lowerFirst(medicine.onlyIf))"
    }
}

// MARK: - 83 Help

// simple help: 911, call buttons and when to call
struct SimpleHelpScreen {

    let base: HelpViewModel

    let title = "Help"
    let call911 = "Call 911"
    let emergencyText = "Chest pain, trouble breathing, heavy bleeding."
    let whenTitle = "When Should I Call?"
    let whenPageTitle = "When to call"
    let editContactsTitle = "Change Who to Call"

    // 112 one card per warning sign, 911 signs first, each with the right call
    struct SignCard: Identifiable {
        let text: String
        let tone: Tone
        let callTitle: String
        let url: URL?
        var isEmergency: Bool { tone == .stop }
        var id: String { text }
    }

    var signCards: [SignCard] {
        let items = base.warningSignItems
        let surgeon = base.contactRows.first { $0.contact.role == .careTeam && $0.phoneURL != nil }
        return (items.filter { $0.tone == .stop } + items.filter { $0.tone != .stop }).map { item in
            item.tone == .stop
                ? SignCard(text: item.text, tone: .stop, callTitle: call911, url: URL(string: "tel:911"))
                : SignCard(text: item.text, tone: .caution, callTitle: surgeon.map { Self.callTitle($0.name) } ?? "Call Surgeon",
                           url: surgeon?.phoneURL)
        }
    }

    // at most two people, 911 is above them
    var calls: [(title: String, row: ContactRow)] {
        base.simpleContacts.filter { $0.phoneURL != nil }.prefix(2).map { (Self.callTitle($0.name), $0) }
    }

    // "Call Surgeon" for the office, "Call Ana" for a person
    static func callTitle(_ name: String) -> String {
        if name.localizedCaseInsensitiveContains("surgeon") { return "Call Surgeon" }
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return "Call \(first)"
    }
}
