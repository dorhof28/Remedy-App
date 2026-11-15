//
//  SimpleLook+ViewModels.swift
//  Remedy
//
//  extra words the simple look needs
//

import Foundation
import SwiftData

// MARK: - Overview buttons (shared shape for every group)

// one big button on an overview screen
struct SimpleGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let tone: Tone
    let count: Int
    let preview: String

    var countText: String { "\(count)" }
    var spokenLabel: String { "\(title), \(count). \(preview)" }

    // "Ibuprofen Naproxen and 1 more"
    static func preview(_ names: [String], show: Int = 2) -> String {
        guard !names.isEmpty else { return "" }
        let shown = names.prefix(show).joined(separator: ", ")
        let more = names.count - show
        return more > 0 ? "\(shown) and \(more) more" : shown
    }
}

// MARK: - Medicines

extension MedicinesViewModel {
    // one button per section most urgent first
    var simpleGroups: [SimpleGroup] {
        sections.map { section in
            SimpleGroup(id: section.id, title: section.title, symbol: section.symbol, tone: section.tone,
                        count: section.rows.count, preview: SimpleGroup.preview(section.rows.map(\.title)))
        }
    }

    // rows for one group
    func rows(inGroup id: String) -> [MedicineRow] {
        sections.first { $0.id == id }?.rows ?? []
    }

    // title for one group
    func groupTitle(_ id: String) -> String {
        sections.first { $0.id == id }?.title ?? title
    }
}

// MARK: - Dose buttons (Taken, Skipped, Undo)

extension MedicineDetailViewModel {

}

// MARK: - Plan

extension PlanViewModel {
    // groups on the plan overview
    enum SimplePlanGroup: String {
        case today, notYet, visits, tasks, ok, comingUp
        case dont, must, may
        // big tiles on the plan screen
        case upcoming, rules
    }

    var simpleGroups: [SimpleGroup] {
        var groups: [SimpleGroup] = []
        let todayEvents = events(onDay: todayID)
        groups.append(SimpleGroup(id: SimplePlanGroup.today.rawValue, title: "Today", symbol: "sun.max.fill", tone: .info,
                                  count: todayEvents.count,
                                  preview: todayEvents.isEmpty ? "Nothing new today" : SimpleGroup.preview(todayEvents.map(\.title))))
        // rules in effect now as short reminders, one group per kind
        for group in nowReminderGroups {
            groups.append(SimpleGroup(id: group.kind.rawValue, title: group.title, symbol: group.symbol, tone: group.tone,
                                      count: group.rows.count, preview: SimpleGroup.preview(group.rows.map(\.text))))
        }
        if showsVisits {
            groups.append(SimpleGroup(id: SimplePlanGroup.visits.rawValue, title: "My visits", symbol: "stethoscope", tone: .info,
                                      count: visitRows.count,
                                      preview: visitRows.first.map { "Next: \($0.title), \(SimpleWording.dayWord(for: $0.appointment.date, now: now))" } ?? ""))
        }
        if showsTasks {
            groups.append(SimpleGroup(id: SimplePlanGroup.tasks.rawValue, title: tasksTitle, symbol: "checklist", tone: .caution,
                                      count: taskRows.filter { !$0.isDone }.count, preview: tasksCountText))
        }
        if showsComingUp {
            groups.append(SimpleGroup(id: SimplePlanGroup.comingUp.rawValue, title: comingUpTitle, symbol: "calendar", tone: .neutral,
                                      count: comingUpRows.count, preview: SimpleGroup.preview(comingUpRows.map(\.title))))
        }
        return groups
    }
}

// MARK: - Today (keep the big card short)

extension BeforeTopCard {
}

extension NowDoseCard {
}

// MARK: - Ask

extension AskViewModel {
    // three ready-made questions fit on one screen
    var simpleSuggestions: [String] { Array(suggestions.prefix(3)) }

    var askAnotherTitle: String { "Ask another question" }
}

// MARK: - Help (big 911, then up to 2 call buttons, signs on their own screen)

extension HelpViewModel {
    var simpleContacts: [ContactRow] { Array(contactRows.prefix(2)) }

    // what "Read to me" says on the warning signs screen
    var spokenWarnings: String {
        "\(warningTitle): " + warningSigns.joined(separator: ". ") + ". \(warningFootnote)"
    }
}

// MARK: - Settings (the few things people change; the rest is one tap away)

extension SettingsViewModel {
    var simpleRemindersTitle: String { "Medicine reminders" }
    var switchToClassicTitle: String { "Switch to the Classic look" }
    var switchToClassicFooter: String { "Smaller text and tabs, with more on each screen." }
}
