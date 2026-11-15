//
//  DayChecklist.swift
//  Remedy
//
//  what is due on a busy day (a stop day, the day before, surgery day, discharge day)
//

import Foundation

// one row on the get ready for surgery list
struct ChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let time: Date?
    let isDone: Bool
    // ticked by the clock, the patient cannot tick it
    var isAutomatic = false
}

// the surgery day list: arrival, stop eating and drinking, what to bring
enum DayChecklist {

    // the arrival time: typed in first then read from the papers
    static func arrival(for plan: some PlanFacts) -> Date? {
        guard let surgeryDate = plan.surgeryDate else { return nil }
        if let typed = plan.arrivalTime { return FastingTimes.onSurgeryDay(typed, surgeryDate: surgeryDate) }
        return FastingTimes.arrival(fromTexts: plan.tasks.map(\.title) + plan.rules.map(\.quote), surgeryDate: surgeryDate)
    }

    // one id per to do that stays the same between launches
    // day + paper + title + place among same titled ones that day
    static func taskID<Plan: PlanFacts>(_ task: Plan.ToDo, in plan: Plan) -> String {
        let same = plan.tasks
            .filter { $0.dueDay == task.dueDay && $0.paperRaw == task.paperRaw && $0.title == task.title }
            .sorted { $0.quote < $1.quote }
        let index = same.firstIndex { $0 === task } ?? 0
        let day = task.dueDay.map(String.init) ?? "none"
        return "task-\(day)-\(task.paperRaw)-\(task.title)-\(index)"
    }

    // texts that can hold fasting rules
    private static func ruleTexts(_ plan: some PlanFacts) -> [String] {
        plan.rules.flatMap { [$0.title, $0.quote] }
    }

    // stops that start that day, leaving out lines a later paper replaced
    private static func stops<Plan: PlanFacts>(on day: Int, plan: Plan,
                                               skipped: SkippedLinesOf<Plan.Medicine.LineID>) -> [Plan.Medicine] {
        plan.medicines.filter {
            $0.isConfirmed && $0.action == .stop && $0.startDay == day
                && !skipped.contains($0.lineID, onDay: day)
        }
    }

    // true when the day needs the live checklist
    static func isBusy<Plan: PlanFacts>(day: Int, plan: Plan,
                                        skipped: SkippedLinesOf<Plan.Medicine.LineID> = SkippedLinesOf()) -> Bool {
        guard let surgeryDate = plan.surgeryDate else { return false }
        if day == -1 || day == 0 { return true }
        if let discharge = plan.dischargeDate, DayMath.dayOffset(of: discharge, from: surgeryDate) == day { return true }
        return !stops(on: day, plan: plan, skipped: skipped).isEmpty
    }

    // everything due that day soonest first, checked holds ids the patient ticked
    static func items<Plan: PlanFacts>(plan: Plan, day: Int, now: Date, checked: Set<String>,
                                       skipped: SkippedLinesOf<Plan.Medicine.LineID> = SkippedLinesOf()) -> [ChecklistItem] {
        guard let surgeryDate = plan.surgeryDate else { return [] }
        var result: [ChecklistItem] = []
        let texts = ruleTexts(plan)
        let startOfDay = DayMath.date(forDay: day, from: surgeryDate)

        for medicine in stops(on: day, plan: plan, skipped: skipped) {
            let id = "stop-\(MedicineText.everydayName(medicine))"
            result.append(ChecklistItem(id: id, title: "Stop \(MedicineText.everydayName(medicine))",
                                        time: nil, isDone: checked.contains(id)))
        }

        for task in plan.tasks where task.dueDay == day {
            result.append(ChecklistItem(id: taskID(task, in: plan), title: task.title, time: nil, isDone: task.isDone))
        }

        if day == -1, let midnight = FastingTimes.foodStop(surgeryDate: surgeryDate, texts: texts) {
            let id = "food-stop"
            result.append(ChecklistItem(id: id, title: "No food after midnight",
                                        time: midnight, isDone: checked.contains(id)))
        }

        if day == 0 {
            let arrival = arrival(for: plan)
            if let end = FastingTimes.clearLiquidsEnd(arrival: arrival, texts: texts) {
                result.append(ChecklistItem(id: "liquids-end", title: "Last clear liquids", time: end, isDone: end <= now, isAutomatic: true))
            }
            if let arrival {
                let id = "arrive"
                let place = plan.hospitalName ?? ""
                result.append(ChecklistItem(id: id, title: place.isEmpty ? "Arrive at the hospital" : "Arrive at \(place)",
                                            time: arrival, isDone: checked.contains(id)))
            }
        }

        if let discharge = plan.dischargeDate, DayMath.dayOffset(of: discharge, from: surgeryDate) == day {
            let id = "discharge"
            result.append(ChecklistItem(id: id, title: "Going home: read your papers",
                                        time: nil, isDone: checked.contains(id)))
        }

        // dated ones first in time order then the rest as listed
        let timed = result.filter { $0.time != nil }.sorted { ($0.time ?? startOfDay) < ($1.time ?? startOfDay) }
        return timed + result.filter { $0.time == nil }
    }

    // the first thing not done yet
    static func next(in items: [ChecklistItem]) -> ChecklistItem? {
        items.first { !$0.isDone }
    }
}
