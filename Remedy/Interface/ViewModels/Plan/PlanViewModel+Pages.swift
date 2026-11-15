//
//  PlanViewModel+Pages.swift
//  Remedy
//
//  the slim header and the day by day list of the plan, both looks
//

import Foundation
import SwiftData

// which screen opens from a row or from Add
enum PlanEditTarget: Identifiable {
    case medicine(MedicineInstruction?)
    case visit(Appointment?)
    case task(CareTask?)

    var id: String {
        switch self {
        case .medicine(let item): return "medicine-\(item.map { "\($0.persistentModelID)" } ?? "new")"
        case .visit(let item): return "visit-\(item.map { "\($0.persistentModelID)" } ?? "new")"
        case .task(let item): return "task-\(item.map { "\($0.persistentModelID)" } ?? "new")"
        }
    }
}

// where today and surgery sit on the slim progress line, both from 0 to 1
struct PlanProgress: Equatable {
    let today: Double
    let surgery: Double

    // the lived part of the line, never empty so a first day still shows
    var filled: Double { min(max(today, 0), 1) }
}

extension PlanViewModel {

    // MARK: - Plan widget words

    // the widget's one header line, "10 days until surgery", "Surgery day" or "Day 3 of recovery"
    var widgetTitle: String { Self.widgetTitle(day: day) }

    // the widget's title for a plan day
    static func widgetTitle(day: Int) -> String {
        switch day {
        case ..<(-1): return "\(-day) days until surgery"
        case -1: return "Surgery tomorrow"
        case 0: return "Surgery day"
        default: return "Day \(day) of recovery"
        }
    }

    // the slim line: where today and surgery sit across the whole journey
    var progress: PlanProgress {
        let days = overviewRows.map(\.stop.day) + [day, 0]
        let range = (days.min() ?? 0)...(days.max() ?? 0)
        return PlanProgress(today: PlanAgenda.position(of: day, in: range), surgery: PlanAgenda.position(of: 0, in: range))
    }

    // MARK: - Journey card words

    // "Getting ready", "Surgery day" or "Recovery · week 1 of 6"
    var journeyPhaseText: String {
        Self.journeyPhaseText(today: day, lastDay: overviewRows.last?.stop.day ?? day)
    }

    static func journeyPhaseText(today: Int, lastDay: Int) -> String {
        if today < 0 { return "Getting ready for surgery" }
        if today == 0 { return "Surgery day" }
        let week = (today - 1) / 7 + 1
        let weeks = (max(lastDay, 1) - 1) / 7 + 1
        return weeks > week ? "Recovery \u{00B7} week \(week) of \(weeks)" : "Recovery \u{00B7} week \(week)"
    }

    // the picked day as a date for the month picker and back
    func date(ofDay picked: Int) -> Date { DayMath.date(forDay: picked, from: plan?.surgeryDate ?? now) }
    func day(of date: Date) -> Int { DayMath.dayOffset(of: date, from: plan?.surgeryDate ?? now) }

    var agenda: Agenda {
        guard let plan else { return Agenda(weeks: [], past: [], anytime: []) }
        return PlanAgenda.build(plan: plan, today: day)
    }

    // "Earlier, 5 days"
    func earlierTitle(_ agenda: Agenda) -> String {
        let count = agenda.pastDayCount
        return "Earlier \u{00B7} \(count) \(count == 1 ? "day" : "days")"
    }

    func toggle(_ task: CareTask, in context: ModelContext) {
        TaskActions.toggle(task, now: now, in: context)
    }
}

extension AgendaItem {
    var symbol: String {
        if let allowed = isAllowedRule { return (allowed ? RuleReminders.Kind.may : .dont).markSymbol }
        return kind.symbol
    }
    var tone: Tone {
        if let allowed = isAllowedRule { return (allowed ? RuleReminders.Kind.may : .dont).tone }
        return kind.tone
    }
    var opensDetail: Bool { medicine != nil || appointment != nil }

    // small words over the title on the day card, like "Visit · 10:15 AM"
    var kindTitle: String {
        switch kind {
        case .surgery: return "Surgery day"
        case .visit: return "Visit"
        case .stopMedicine, .startMedicine, .endMedicine: return "Medicine change"
        case .task: return isDone ? "Done" : "To do"
        case .ruleChange:
            if let allowed = isAllowedRule { return (allowed ? RuleReminders.Kind.may : .dont).label }
            return "Instruction"
        }
    }
    var caption: String { [kindTitle, time].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ") }

    // read out as one line
    var spokenLabel: String {
        [title, time, detail].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// MARK: - More pages

// a page pushed from the plan's quick row or More card
enum PlanPage: String, Hashable, CaseIterable {
    case journey, instructions, surgeryDay, checkIns, papers, whatChanged, paperNotes, firstWeek
}

extension PlanViewModel {

    var moreTitle: String { "More" }

    // page titles, the same on the row's label and on the page
    func title(of page: PlanPage) -> String {
        switch page {
        case .journey: return overviewTitle
        case .instructions: return instructionsTitle
        case .surgeryDay: return "Surgery day details"
        case .checkIns: return "Check-ins"
        case .papers: return "Papers"
        case .whatChanged: return WhatChangedViewModel.screenTitle
        case .paperNotes: return PaperCheckViewModel.blueSectionTitle
        case .firstWeek: return PreviewWeekViewModel(plan: plan).buttonTitle
        }
    }

}
