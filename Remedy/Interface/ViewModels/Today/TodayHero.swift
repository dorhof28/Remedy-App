//
//  TodayHero.swift
//  Remedy
//
//  progress ring and alert-style to-dos for the today screen, both looks
//

import Foundation
import SwiftData

// a to-do that needs the patient to fill something in
struct TodayAction: Identifiable, Equatable {
    enum Kind { case hospitalDetails }
    let kind: Kind
    let title: String
    let detail: String
    let symbol: String
    var id: String { title }

    var spokenLabel: String { "\(title). \(detail)" }
    let spokenHint = "Double-tap to fill it in."
}

extension TodayViewModel {

    // MARK: - Progress ring

    // MARK: - Alert-style to-dos

    // arrival time and hospital are asked for here, never as a form on Today
    var hospitalAction: TodayAction? {
        guard let plan, plan.surgeryDate != nil, layout == .beforeSurgery || layout == .surgeryDay,
              TonightHeadsUp.asksForPlace(daysToSurgery: -day) else { return nil }
        let noArrival = plan.arrivalTime == nil && DayChecklist.arrival(for: plan) == nil
        let noHospital = (plan.hospitalName ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        guard noArrival || noHospital else { return nil }
        let title = noArrival && noHospital ? "Add arrival time and hospital"
            : (noArrival ? "Add arrival time" : "Add hospital")
        return TodayAction(kind: .hospitalDetails, title: title,
                           detail: "Sets your fasting times",
                           symbol: "building.2.fill")
    }

}

// MARK: - One list for today

extension TodayViewModel {

}

extension TodayViewModel {
}

// MARK: - Next item for the header

extension TodayViewModel {

}

// MARK: - Missed doses, said once

extension TodayViewModel {

    var missedCount: Int { todaySlots.filter { $0.state == .missed }.count }

}

// MARK: - The one next thing in the header

extension TodayViewModel {

    // "Aspirin 325 mg (Bayer)" becomes "Aspirin"
    static func shortName(_ name: String) -> String {
        var short = name
        if let paren = short.range(of: " (") { short = String(short[..<paren.lowerBound]) }
        if let strength = short.range(of: #"\s\d[\d.,]*\s?(mg|mcg|g|ml|mL|units?|%)\b.*$"#, options: .regularExpression) {
            short.removeSubrange(strength)
        }
        let trimmed = short.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? name : trimmed
    }

}

// MARK: - Calm words for the list and the hero

extension TodayViewModel {

    // the short what to do line under the missed title
    static func missedAdvice(count: Int) -> String? {
        guard count > 0 else { return nil }
        let it = count == 1 ? "it" : "them"
        return "Not taken yet? Ask your care team before taking \(it) late."
    }

    var missedAdvice: String? { Self.missedAdvice(count: missedCount) }

}

// MARK: - The title and the one line under it

extension TodayViewModel {

    // "Thursday, Nov 19"
    static func weekdayDate(_ date: Date) -> String {
        weekdayDateFormatter.string(from: date)
    }

    // "Tuesday"
    static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date) }

    private static let weekdayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    // the next visit from now on, or only from tomorrow on
    func nextVisit(afterToday: Bool) -> Appointment? {
        let calendar = DayMath.calendar
        let start = afterToday ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now : now
        return (plan?.appointments ?? []).filter { $0.date >= start }.min { $0.date < $1.date }
    }
}

// MARK: - Today's one list

extension TodayViewModel {

    // the to-dos that are today's: due today, late, or a before-surgery one with no day
    var todayTasks: [TaskRow] {
        guard let plan else { return [] }
        let todayStart = DayMath.calendar.startOfDay(for: now)
        return plan.tasks
            .filter { task in
                if task.isDone { return (task.doneAt ?? .distantPast) >= todayStart }
                if PlanWording.isOnToday(task, today: day) { return true }
                return layout != .afterSurgery && task.paper == .beforeSurgery && task.dueDay == nil
            }
            .sorted { ($0.dueDay ?? Int.max) < ($1.dueDay ?? Int.max) }
            .map { task in
                TaskRow(task: task, title: task.title,
                        detail: PlanWording.taskDueText(task, today: day, surgeryDate: surgeryDate),
                        isDone: task.isDone, isLate: PlanWording.taskIsLate(task, today: day))
            }
    }

    // open to-dos up to surgery day, soonest first, for the get ready list
    var readyTasks: [TaskRow] {
        guard let plan else { return [] }
        return plan.tasks
            .filter { !$0.isDone && ($0.dueDay ?? 0) <= 0 && ($0.dueDay != nil || $0.paper == .beforeSurgery) }
            .sorted { ($0.dueDay ?? Int.max) < ($1.dueDay ?? Int.max) }
            .map { task in
                TaskRow(task: task, title: task.title,
                        detail: PlanWording.taskDueText(task, today: day, surgeryDate: surgeryDate),
                        isDone: false, isLate: PlanWording.taskIsLate(task, today: day))
            }
    }

    // the one count for Today: scheduled doses + to-dos (the check-in and stop-today count as to-dos)
    func dayProgress(checkIn: CheckIn?) -> (done: Int, total: Int) {
        var done = 0, total = 0
        func count(_ isDone: Bool) { total += 1; if isDone { done += 1 } }
        // set-time doses, taken or skipped is done
        for row in doseSections.flatMap(\.rows) { count(row.state == .taken || row.state == .skipped) }
        // stop these today
        if layout == .beforeSurgery, !stopsStartingToday.isEmpty { count(beforeTopCard.isDone) }
        // the daily check-in after surgery
        if showsCheckIn { count(checkIn != nil) }
        // to-dos
        for row in todayTasks { count(row.isDone) }
        return (done, total)
    }
}

// MARK: - Around the list

extension TodayViewModel {

    // only in the evening: a medicine that stops tomorrow or a visit early tomorrow, the rest of the day nothing
    var tonight: [ComingUpRow] {
        guard layout != .noPlan, layout != .needsSurgeryDate else { return [] }
        let stopping = futureStopDays.first { $0.day == day + 1 }?.medicines ?? []
        let names = Self.uniqueNames(stopping.map { Self.shortName(MedicineText.everydayName($0)) })
        let tomorrow = DayMath.calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let visits = (plan?.appointments ?? []).filter { DayMath.calendar.isDate($0.date, inSameDayAs: tomorrow) }
        let items = TonightHeadsUp.items(minuteOfDay: DayMath.minuteOfDay(now), stopsTomorrow: names,
                                         visitsTomorrow: visits.map { .init(title: $0.title, minute: DayMath.minuteOfDay($0.date)) })
        return items.map { item in
            switch item.kind {
            case .stop:
                return ComingUpRow(id: item.id, kind: .stop, title: item.title, detail: item.detail, detailTone: .caution)
            case .visit:
                return ComingUpRow(id: item.id, kind: .visit, title: item.title, detail: item.detail,
                                   visit: visits.first { $0.title == item.title })
            }
        }
    }

    var tonightHeader: String { "For tomorrow" }

    // "1 of 3 · 10 reps each"
    func goalDetail(_ tile: GoalTile) -> String {
        [tile.countText, tile.amountText].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

}

private extension String {
}

// MARK: - Rules in effect today

// one rule from the papers that applies today, in any phase
struct TodayRuleRow: Identifiable, Equatable {
    let id: String
    let title: String
    // the time or the end, "From midnight tonight", "Until 5:00 AM"
    let detail: String
    let isAllowed: Bool
    let startsToday: Bool

    var row: TodayRow {
        TodayRow(id: id, symbol: isAllowed ? "checkmark.circle.fill" : "hand.raised.fill",
                 tone: isAllowed ? .good : .caution, title: title, detail: detail)
    }
}

extension TodayViewModel {

    static let rulesTodayHeader = "Rules for today"

    // every rule active today, the ones that start today first, then the don'ts, then what is allowed
    func rulesInEffectToday() -> [TodayRuleRow] {
        guard let plan, plan.surgeryDate != nil, layout != .noPlan, layout != .needsSurgeryDate else { return [] }
        let arrival = DayChecklist.arrival(for: plan)
        let rows = plan.rules
            .filter { !$0.isCallSign && DoseSchedule.isActive($0, on: day) }
            .map { rule -> TodayRuleRow in
                let status = PlanWording.ruleStatus(rule, today: day, surgeryDate: surgeryDate)
                let start = DoseSchedule.startDay(of: rule)
                let detail = ruleTimeWords(rule, arrival: arrival) ?? status.detail
                // a second line that only repeats the title is dropped
                let repeats = rule.title.lowercased().contains(detail.lowercased())
                return TodayRuleRow(id: "rule-\(rule.persistentModelID.hashValue)", title: rule.title,
                                    detail: repeats ? "" : detail,
                                    isAllowed: rule.isAllowed, startsToday: start == day)
            }
            // what is allowed shows only on the day it starts, the rest of the time Today keeps to the limits
            .filter { !$0.isAllowed || $0.startsToday }
        return rows.enumerated().sorted { a, b in
            func rank(_ row: TodayRuleRow) -> Int { row.startsToday ? 0 : (row.isAllowed ? 2 : 1) }
            if rank(a.element) != rank(b.element) { return rank(a.element) < rank(b.element) }
            return a.offset < b.offset
        }.map(\.element)
    }

    // the clock part of a rule, nil when the papers give none
    private func ruleTimeWords(_ rule: CareRule, arrival: Date?) -> String? {
        let own = [rule.title, rule.quote]
        let lower = rule.title.lowercased()
        // clear liquids end a set time before arrival
        if lower.contains("clear liquid") {
            if let end = FastingTimes.clearLiquidsEnd(arrival: arrival, texts: own) {
                return "Until \(DayMath.timeText(of: end))"
            }
            if lower.contains("until"), let minute = FastingTimes.clockMinute(in: rule.title) {
                return "Until \(DayMath.timeText(minute))"
            }
            if let hours = FastingTimes.hoursBefore(in: rule.title) {
                return "Until \(hours) \(hours == 1 ? "hour" : "hours") before you arrive"
            }
            return nil
        }
        // no food starts at midnight and lasts until surgery
        if !rule.isAllowed, FastingTimes.foodStop(surgeryDate: surgeryDate, texts: [rule.title]) != nil {
            if day < 0 { return "From midnight tonight" }
            if day == 0 { return "Since midnight" }
        }
        if !rule.isAllowed, lower.contains("until") || lower.contains("after"), let minute = FastingTimes.clockMinute(in: rule.title) {
            return (lower.contains("until") ? "Until " : "After ") + DayMath.timeText(minute)
        }
        return nil
    }
}
