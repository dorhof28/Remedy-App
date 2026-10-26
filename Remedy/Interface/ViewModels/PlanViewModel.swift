//
//  PlanViewModel.swift
//  Remedy
//
//  plan tab for both looks
//

import Foundation
import SwiftData

// MARK: - Display data

// one thing on the picked day
struct PlanEventRow: Identifiable {
    let event: DayEvent
    let symbol: String
    let tone: Tone

    var id: String { event.id }
    var title: String { event.title }
    var detail: String { event.detail }
    var medicine: MedicineInstruction? { event.medicine }
    var appointment: Appointment? { event.appointment }
    var opensDetail: Bool { medicine != nil || appointment != nil }
}

// one can / can't rule
struct RuleRow: Identifiable {
    let rule: CareRule
    let headline: String        // "Not yet" / "From Sun, Nov 1"
    let detail: String          // "Until Thu, Nov 12"
    let tone: Tone
    let symbol: String

    var id: PersistentIdentifier { rule.persistentModelID }
    var title: String { rule.title }
    var spokenLabel: String { "\(rule.title). \(headline). \(detail)" }
}

// one visit in the list
struct VisitRow: Identifiable {
    let appointment: Appointment
    let month: String           // "NOV"
    let dayNumber: String       // "2"
    let weekday: String         // "Mon"
    let title: String           // "Physical therapy"
    let detail: String          // "11:00 AM · Outpatient Rehab"
    let relative: String        // "in 4 days"

    var id: PersistentIdentifier { appointment.persistentModelID }
    var spokenLabel: String { "\(title), \(weekday) \(month) \(dayNumber), \(detail), \(relative)" }
}

// one key day on the journey overview
struct JourneyStopRow: Identifiable {
    let stop: JourneyStop
    let symbol: String
    let tone: Tone
    let labelText: String       // "3 days before surgery"
    let stateText: String       // "Today" "Next" "Done" "in 5 days"

    var id: Int { stop.day }
    var isFaded: Bool { stop.state == .done }
    var spokenLabel: String {
        "\(stop.weekday) \(stop.month) \(stop.dayNumber), \(labelText). \(stateText). \(stop.titles.joined(separator: ". "))"
    }
}

// MARK: - ViewModel

struct PlanViewModel {

    let plan: CarePlan?
    let now: Date
    let day: Int

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        self.day = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
    }

    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    // MARK: - Words

    let title = "Plan"
    let emptyTitle = "No plan yet"
    let emptyDetail = "Your day-by-day plan shows up here after you scan your papers and add your surgery date."
    let journeyTitle = "Your journey"
    let notYetTitle = "Not yet"
    let visitsTitle = "Visits"
    let tasksTitle = "To do"
    let okTitle = "OK to do"
    let comingUpTitle = "Coming up"
    let todayButtonTitle = "Today"
    // empty day text
    func emptyDayText(_ picked: Int) -> String {
        let when = picked == day ? "today" : "on this day"
        return "Nothing new \(when). Keep following your papers."
    }

    // the plan can only be drawn once we know the surgery date
    var hasPlan: Bool { plan?.surgeryDate != nil }

    // MARK: - Journey

    var journeyDays: [JourneyDay] {
        guard let plan else { return [] }
        return Journey.days(in: Journey.range(for: plan, today: day), plan: plan, today: day)
    }

    // the day picked when the screen opens
    var todayID: Int { day }

    // "Thursday October 29"
    func dayTitle(_ picked: Int) -> String {
        DayMath.longDate(forDay: picked, from: surgeryDate)
    }

    // "Today · 4 days before surgery" / "Surgery day · in 4 days"
    func daySubtitle(_ picked: Int) -> String {
        let words = upperFirst(DayMath.surgeryWords(forDay: picked))
        if picked == day { return "Today · \(words)" }
        return "\(words) · \(DayMath.relative(daysFromToday: picked - day))"
    }

    // what happens on a day most important first
    func events(onDay picked: Int) -> [PlanEventRow] {
        guard let plan else { return [] }
        return Journey.events(onDay: picked, plan: plan).map { event in
            PlanEventRow(event: event, symbol: symbol(for: event.kind), tone: tone(for: event.kind))
        }
    }

    // "Back to today" only shows when another day is picked
    func showsTodayButton(picked: Int) -> Bool { picked != day }

    // MARK: - Journey overview

    let overviewTitle = "The whole journey"

    // every key day with its icon and where it sits
    var overviewRows: [JourneyStopRow] {
        guard let plan else { return [] }
        return Journey.stops(plan: plan, today: day).map { stop in
            let state: String
            switch stop.state {
            case .done: state = "Done"
            case .today: state = "Today"
            case .next: state = "Next"
            case .later: state = DayMath.relative(daysFromToday: stop.day - day)
            }
            return JourneyStopRow(stop: stop, symbol: stop.kind?.symbol ?? "smallcircle.filled.circle",
                                  tone: stop.kind?.tone ?? .info, labelText: upperFirst(stop.label), stateText: state)
        }
    }
    var overviewCountText: String { "\(overviewRows.count) key days" }

    // MARK: - Rules

    private var ruleStatuses: [(rule: CareRule, status: RuleStatus)] {
        (plan?.rules ?? []).map { (rule: $0, status: PlanWording.ruleStatus($0, today: day, surgeryDate: surgeryDate)) }
    }

    // in effect now and not allowed
    var notYetRows: [RuleRow] { ruleRows(kinds: [.notAllowed]) }
    var showsNotYet: Bool { !notYetRows.isEmpty }
    var notYetCountText: String { "\(notYetRows.count)" }

    // in effect now and allowed
    var okRows: [RuleRow] { ruleRows(kinds: [.allowed]) }
    var showsOk: Bool { !okRows.isEmpty }
    var okCountText: String { "\(okRows.count)" }

    // start later soonest first
    var comingUpRows: [RuleRow] {
        ruleStatuses
            .filter { $0.status.kind == .allowedLater || $0.status.kind == .notAllowedLater }
            .sorted { ($0.rule.startDay ?? 0) < ($1.rule.startDay ?? 0) }
            .map { ruleRow($0.rule, $0.status) }
    }
    var showsComingUp: Bool { !comingUpRows.isEmpty }
    var comingUpCountText: String { "\(comingUpRows.count)" }

    // MARK: - Visits

    // from today on soonest first
    var visitRows: [VisitRow] {
        let todayStart = DayMath.calendar.startOfDay(for: now)
        return (plan?.appointments ?? [])
            .filter { $0.date >= todayStart }
            .sorted { $0.date < $1.date }
            .map { visit in
                let parts = DateParts(visit.date)
                let place = visit.place.isEmpty ? "" : " · \(visit.place)"
                return VisitRow(appointment: visit,
                                month: parts.month,
                                dayNumber: parts.day,
                                weekday: parts.weekday,
                                title: visit.title,
                                detail: DayMath.timeText(of: visit.date) + place,
                                relative: DateParts.relative(visit.date, now: now))
            }
    }
    var showsVisits: Bool { !visitRows.isEmpty }
    var visitsCountText: String { "\(visitRows.count)" }

    // MARK: - To do

    // open tasks by due day then done ones
    var taskRows: [TaskRow] {
        let tasks = plan?.tasks ?? []
        let open = tasks.filter { !$0.isDone }.sorted { ($0.dueDay ?? Int.max) < ($1.dueDay ?? Int.max) }
        let done = tasks.filter { $0.isDone }
        return (open + done).map { task in
            TaskRow(task: task, title: task.title,
                    detail: PlanWording.taskDueText(task, today: day, surgeryDate: surgeryDate),
                    isDone: task.isDone)
        }
    }
    var showsTasks: Bool { !taskRows.isEmpty }

    // "2 to do"
    var tasksCountText: String {
        let open = (plan?.tasks ?? []).filter { !$0.isDone }.count
        return open == 0 ? "All done" : "\(open) to do"
    }

    // MARK: - Actions

    // ticks a to do
    func toggle(_ row: TaskRow, in context: ModelContext) {
        TaskActions.toggle(row.task, now: now, in: context)
    }

    // MARK: - Private

    private func ruleRows(kinds: [RuleStatusKind]) -> [RuleRow] {
        ruleStatuses.filter { kinds.contains($0.status.kind) }.map { ruleRow($0.rule, $0.status) }
    }

    private func ruleRow(_ rule: CareRule, _ status: RuleStatus) -> RuleRow {
        let tone: Tone
        let symbol: String
        switch status.kind {
        case .notAllowed: tone = .stop; symbol = "xmark.circle.fill"
        case .allowed: tone = .good; symbol = "checkmark.circle.fill"
        case .allowedLater: tone = .info; symbol = "calendar"
        case .notAllowedLater: tone = .caution; symbol = "calendar.badge.exclamationmark"
        case .ended: tone = .neutral; symbol = "checkmark.seal"
        }
        return RuleRow(rule: rule, headline: status.headline, detail: status.detail, tone: tone, symbol: symbol)
    }

    private func symbol(for kind: DayEventKind) -> String {
        switch kind {
        case .surgery: return "star.circle.fill"
        case .stopMedicine: return "nosign"
        case .visit: return "stethoscope"
        case .task: return "checklist"
        case .ruleChange: return "figure.walk"
        case .startMedicine: return "pills.fill"
        case .endMedicine: return "checkmark.seal"
        }
    }

    private func tone(for kind: DayEventKind) -> Tone {
        switch kind {
        case .surgery, .visit, .startMedicine: return .info
        case .stopMedicine: return .stop
        case .task: return .caution
        case .ruleChange, .endMedicine: return .neutral
        }
    }

    private func upperFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}

// MARK: - Colours for the journey dots (shared by both looks)

extension DayEventKind {
    var tone: Tone {
        switch self {
        case .stopMedicine: return .stop
        case .task: return .caution
        case .visit, .surgery: return .info
        case .ruleChange, .startMedicine, .endMedicine: return .neutral
        }
    }
}
