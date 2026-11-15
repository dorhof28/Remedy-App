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

// the plan for any day: rules, events and the agenda, shared by both looks
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

    static let screenTitle = "Plan"
    let title = PlanViewModel.screenTitle
    let emptyTitle = "No plan yet"
    let emptyDetail = "Your day-by-day plan shows up here after you scan your papers and add your surgery date."
    let journeyTitle = "Your journey"
    let notYetTitle = "Not yet"
    let visitsTitle = "Visits"
    let tasksTitle = "To-dos"
    let okTitle = "Fine to do"
    let comingUpTitle = "Coming up"
    // empty day text
    func emptyDayText(_ picked: Int) -> String {
        let when = picked == day ? "today" : "on this day"
        return "Nothing new \(when). Keep following your papers."
    }

    // the plan can only be drawn once we know the surgery date
    var hasPlan: Bool { plan?.surgeryDate != nil }

    // MARK: - Journey

    // the day picked when the screen opens
    var todayID: Int { day }

    // "Thursday October 29"
    func dayTitle(_ picked: Int) -> String {
        DayMath.longDate(forDay: picked, from: surgeryDate)
    }

    // "Today" or "Tomorrow · in 2 days", surgery day is marked only by the calendar cell and its own heading
    func daySubtitle(_ picked: Int) -> String {
        Self.daySubtitle(picked: picked, today: day)
    }

    static func daySubtitle(picked: Int, today: Int) -> String {
        if picked == today { return "Today" }
        return DayMath.relative(daysFromToday: picked - today).prefix(1).uppercased()
            + DayMath.relative(daysFromToday: picked - today).dropFirst()
    }

    // what happens on a day most important first
    func events(onDay picked: Int) -> [PlanEventRow] {
        guard let plan else { return [] }
        return Journey.events(onDay: picked, plan: plan).map { event in
            PlanEventRow(event: event, symbol: symbol(for: event.kind), tone: tone(for: event.kind))
        }
    }

    // MARK: - Journey overview

    let overviewTitle = "Whole journey"

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

    // MARK: - Rules

    private var ruleStatuses: [(rule: CareRule, status: RuleStatus)] { ruleStatuses(onDay: day) }

    // each rule's status on a day
    private func ruleStatuses(onDay picked: Int) -> [(rule: CareRule, status: RuleStatus)] {
        (plan?.rules ?? []).map { (rule: $0, status: PlanWording.ruleStatus($0, today: picked, surgeryDate: surgeryDate)) }
    }

    // rules in effect on a day, not allowed first
    func activeRuleRows(onDay picked: Int) -> [RuleRow] {
        let statuses = ruleStatuses(onDay: picked)
        return (statuses.filter { $0.status.kind == .notAllowed } + statuses.filter { $0.status.kind == .allowed })
            .map { ruleRow($0.rule, $0.status) }
    }

    // in effect now and not allowed
    var notYetRows: [RuleRow] { ruleRows(kinds: [.notAllowed]) }
    var showsNotYet: Bool { !notYetRows.isEmpty }

    // in effect now and allowed
    var okRows: [RuleRow] { ruleRows(kinds: [.allowed]) }

    // start later soonest first
    var comingUpRows: [RuleRow] {
        ruleStatuses
            .filter { $0.status.kind == .allowedLater || $0.status.kind == .notAllowedLater }
            .sorted { ($0.rule.startDay ?? 0) < ($1.rule.startDay ?? 0) }
            .map { ruleRow($0.rule, $0.status) }
    }
    var showsComingUp: Bool { !comingUpRows.isEmpty }

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

    // MARK: - To do

    // open tasks by due day then done ones
    var taskRows: [TaskRow] {
        let tasks = plan?.tasks ?? []
        let open = tasks.filter { !$0.isDone }.sorted { ($0.dueDay ?? Int.max) < ($1.dueDay ?? Int.max) }
        let done = tasks.filter { $0.isDone }
        return (open + done).map { task in
            TaskRow(task: task, title: task.title,
                    detail: PlanWording.taskDueText(task, today: day, surgeryDate: surgeryDate),
                    isDone: task.isDone, isLate: PlanWording.taskIsLate(task, today: day))
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

// MARK: - Classic single screen: what changes on a day

extension PlanViewModel {

    // the words for a medicine that starts, stops or comes back on a day, nil = nothing changes
    static func changeWords(action: MedicineAction, startDay: Int?, endDay: Int?, on picked: Int) -> String? {
        if action == .stop {
            if startDay == picked { return "Stop" }
            // a stop that ends means it is fine to take again
            if endDay == picked { return "Restart" }
            return nil
        }
        if startDay == picked { return "Start" }
        if endDay == picked { return "Last day" }
        return nil
    }

    // blocks for the classic day: no medicine list, only changes, visits, to dos and rules
    func changeSections(onDay picked: Int) -> [DaySection] {
        let skipped = plan.map { PaperCheckReport.of($0).skipped }
        var result = ruleChangesOnly(sections(onDay: picked), onDay: picked)
            .filter { $0.id != "take" && $0.id != "dont" }
        let changes: [AgendaItem] = (plan?.medicines ?? [])
            .filter { $0.isConfirmed && !(skipped?.contains($0.persistentModelID, onDay: picked) ?? false) }
            .compactMap { medicine in
                guard let words = Self.changeWords(action: medicine.action, startDay: medicine.startDay,
                                                   endDay: medicine.endDay, on: picked) else { return nil }
                let isStop = words == "Stop" || words == "Last day"
                var detail = [words]
                if medicine.action == .stop, !medicine.reason.isEmpty { detail.append(medicine.reason) }
                return AgendaItem(id: "change-\(medicine.persistentModelID)", kind: isStop ? .stopMedicine : .startMedicine,
                                  title: MedicineText.everydayName(medicine),
                                  detail: detail.joined(separator: " \u{00B7} "), medicine: medicine)
            }
            .sorted { $0.title < $1.title }
        if !changes.isEmpty {
            // after visits, before to dos
            let at = result.firstIndex { $0.id == "todo" || $0.id == "rules" } ?? result.endIndex
            result.insert(DaySection(id: "changes", title: "Medicine changes", symbol: "pills.fill",
                                     tone: .info, items: changes), at: at)
        }
        return result
    }

    // rules in effect live in the rules card, a day only lists the ones that start or end on it
    func ruleChangesOnly(_ sections: [DaySection], onDay picked: Int) -> [DaySection] {
        let changing = Set((plan?.rules ?? []).filter { $0.startDay == picked || $0.endDay == picked }
            .map { "rule-\($0.persistentModelID)" })
        return sections.compactMap { section in
            guard section.id == "rules" else { return section }
            let items = section.items.filter { changing.contains($0.id) }
            return items.isEmpty ? nil : DaySection(id: section.id, title: section.title, symbol: section.symbol,
                                                    tone: section.tone, items: items)
        }
    }

    // the simple calendar's day: everything with the medicines, but rules only when they change
    func simpleDayItems(onDay picked: Int) -> [AgendaItem] {
        ruleChangesOnly(sections(onDay: picked), onDay: picked).flatMap(\.items)
    }

    // the medicines to take on a day
    func takeItems(onDay picked: Int) -> [AgendaItem] {
        sections(onDay: picked).first { $0.id == "take" }?.items ?? []
    }

}

// MARK: - Calendar that scrolls back and forward (classic)

extension PlanViewModel {

    // "November 2026", one shared formatter so scrolling does not make a new one each time
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

}

// MARK: - Words for the pages under More

extension PlanViewModel {

    var papersListTitle: String { "Added papers" }
}

// MARK: - Whole journey words

extension JourneyStopRow {
    // "Today" or "Nov 19"
    var dateText: String {
        stop.state == .today ? "Today" : stop.date.formatted(.dateTime.month(.abbreviated).day())
    }
    var isSurgery: Bool { stop.day == 0 }
    var isToday: Bool { stop.state == .today }
    // the first thing that happens, surgery day says so
    var titleText: String { isSurgery ? "Surgery" : (stop.titles.first ?? "") }
    // the rest of the day, or where it sits from surgery
    var secondLine: String {
        let rest = isSurgery ? stop.titles : Array(stop.titles.dropFirst())
        return rest.isEmpty ? labelText : rest.joined(separator: ", ")
    }
}
