//
//  DayScreen.swift
//  Remedy
//
//  words for one day of the plan (screen 42): visits, medicines, to-dos and rules, with before and next
//

import Foundation
import SwiftData

// a titled group of rows on a day page
struct DayGroup: Identifiable {
    let id: String
    let title: String
    let lines: [DayLine]
}

// one row on a day page
struct DayLine: Identifiable {
    let id: String
    let symbol: String
    var tone: Tone = .info
    let title: String
    var subtitle: String = ""
    var medicine: MedicineInstruction?
    var appointment: Appointment?
    var task: CareTask?

    var opens: Bool { medicine != nil || appointment != nil || task != nil }
}

// one plan day: medicines, visits, rules and to-dos on it
struct DayScreen {

    let plan: CarePlan?
    let day: Int
    let now: Date
    private let base: PlanViewModel

    init(plan: CarePlan?, day: Int, now: Date) {
        self.plan = plan
        self.day = day
        self.now = now
        self.base = PlanViewModel(plan: plan, now: now)
    }

    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    let readAloudButton = "Read Aloud"
    let emptyText = "Nothing on your papers for this day."

    // "Mon, Nov 16"
    var title: String { dateText(day) }

    func dateText(_ day: Int) -> String { DayMath.shortDate(forDay: day, from: surgeryDate) }

    // "Day 7 after surgery · coming up. Nothing to do yet."
    var subtitle: String {
        let first: String
        if day > 0 { first = "Day \(day) after surgery" } else if day == 0 { first = "Surgery day" }
        else { first = PlainText.upperFirst(DayMath.surgeryWords(forDay: day)) }
        if day == base.day { return "\(first) \u{00B7} today." }
        if day < base.day { return "\(first) \u{00B7} already past." }
        return "\(first) \u{00B7} coming up. Nothing to do yet."
    }

    var previousTitle: String { dateText(day - 1) }
    var nextTitle: String { dateText(day + 1) }

    var groups: [DayGroup] {
        base.sections(onDay: day).compactMap { section in
            let title: String
            switch section.id {
            case "surgery": title = "Surgery"
            case "visits": title = section.items.count == 1 ? "Visit" : "Visits"
            case "take": title = "Medicines"
            case "dont": title = "Stopped"
            case "todo": title = "To-dos"
            case "rules": title = "Rules"
            default: title = section.title
            }
            let lines = section.items.map { item -> DayLine in
                switch item.kind {
                case .visit:
                    let place = item.appointment?.place ?? ""
                    return DayLine(id: item.id, symbol: "calendar", title: item.title,
                                   subtitle: [item.time, place].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "),
                                   appointment: item.appointment)
                case .stopMedicine:
                    return DayLine(id: item.id, symbol: "nosign", tone: .stop, title: item.title, subtitle: item.detail,
                                   medicine: item.medicine)
                case .startMedicine, .endMedicine:
                    return DayLine(id: item.id, symbol: "pills", title: item.title, subtitle: item.detail,
                                   medicine: item.medicine)
                case .task:
                    return DayLine(id: item.id, symbol: item.isDone ? "checkmark.circle" : "circle",
                                   tone: item.isDone ? .good : .info, title: item.title, subtitle: item.detail, task: item.task)
                case .ruleChange:
                    let allowed = item.isAllowedRule ?? false
                    return DayLine(id: item.id, symbol: allowed ? "checkmark.circle" : "nosign", tone: allowed ? .good : .stop,
                                   title: item.title, subtitle: item.detail)
                case .surgery:
                    return DayLine(id: item.id, symbol: "bed.double", title: item.title,
                                   subtitle: [item.time, item.detail].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
                }
            }
            return DayGroup(id: section.id, title: title, lines: lines)
        }
    }

    // what read aloud says
    var spoken: String {
        ([title, subtitle] + groups.flatMap { group in
            [group.title + "."] + group.lines.map { [$0.title, $0.subtitle].filter { !$0.isEmpty }.joined(separator: ", ") + "." }
        }).joined(separator: " ")
    }
}
