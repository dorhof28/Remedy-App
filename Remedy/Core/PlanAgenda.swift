//
//  PlanAgenda.swift
//  Remedy
//
//  the plan as days grouped by week, built from the same events as the journey
//

import Foundation

// one line on a day, persistence names the saved kind AgendaItem
struct AgendaItemOf<Plan: PlanFacts>: Identifiable {
    let id: String
    let kind: DayEventKind
    let title: String
    let detail: String
    var time: String = ""
    var isDone = false
    var medicine: Plan.Medicine?
    var appointment: Plan.Visit?
    var task: Plan.ToDo?
    // set on a rule line, true = allowed
    var isAllowedRule: Bool?
}

// one day with something on it
struct AgendaDayOf<Plan: PlanFacts>: Identifiable {
    let id: Int                 // plan day
    let date: Date
    let title: String           // "Today" "Tomorrow" "Fri, Nov 13"
    let subtitle: String        // "4 days before surgery"
    let isToday: Bool
    let isPast: Bool
    let items: [AgendaItemOf<Plan>]
}

// one week on the plan screen
struct AgendaWeekOf<Plan: PlanFacts>: Identifiable {
    let id: Int                 // plan day the week starts on
    let title: String           // "This week" "Next week" "Nov 16 to 22"
    let days: [AgendaDayOf<Plan>]
}

// the whole plan as weeks from today, past days and items with no day
struct AgendaOf<Plan: PlanFacts> {
    // today and later
    let weeks: [AgendaWeekOf<Plan>]
    // before today
    let past: [AgendaWeekOf<Plan>]
    // open to-dos with no day
    let anytime: [AgendaItemOf<Plan>]

    var pastDayCount: Int { past.reduce(0) { $0 + $1.days.count } }
    var todayDay: AgendaDayOf<Plan>? { weeks.flatMap(\.days).first { $0.isToday } }
}

// builds the plan screen's day by day list
enum PlanAgenda {

    // "Surgery in 4 days" "Surgery day" "Day 3 after surgery"
    static func headline(day: Int) -> String {
        switch day {
        case 0: return "Surgery day"
        case -1: return "Surgery tomorrow"
        case ..<0: return "Surgery in \(-day) days"
        case 1: return "Day 1 after surgery"
        default: return "Day \(day) after surgery"
        }
    }

    // where a day sits along a range, 0 at the start and 1 at the end
    static func position(of day: Int, in range: ClosedRange<Int>) -> Double {
        let width = range.upperBound - range.lowerBound
        guard width > 0 else { return 0.5 }
        let clamped = min(max(day, range.lowerBound), range.upperBound)
        return Double(clamped - range.lowerBound) / Double(width)
    }

    // every day from the plan's range, grouped into weeks
    static func build<Plan: PlanFacts>(plan: Plan, today: Int) -> AgendaOf<Plan> {
        guard let surgeryDate = plan.surgeryDate else { return AgendaOf(weeks: [], past: [], anytime: []) }

        // open to-dos that slipped past show on today so they are not lost
        let overdue = plan.tasks.filter { !$0.isDone && ($0.dueDay ?? today) < today }
        var days = Set(Journey.range(for: plan, today: today).filter { !items(onDay: $0, plan: plan, today: today, overdue: overdue).isEmpty })
        days.insert(today)

        let built: [AgendaDayOf<Plan>] = days.sorted().map { day in
            let date = DayMath.date(forDay: day, from: surgeryDate)
            return AgendaDayOf(id: day, date: date, title: dayTitle(day, today: today, date: date),
                             subtitle: upperFirst(DayMath.surgeryWords(forDay: day)),
                             isToday: day == today, isPast: day < today,
                             items: items(onDay: day, plan: plan, today: today, overdue: overdue))
        }

        let anytime: [AgendaItemOf<Plan>] = plan.tasks.filter { !$0.isDone && $0.dueDay == nil }.map { taskItem($0, detail: "No day set") }
        return AgendaOf(weeks: group(built.filter { !$0.isPast }, today: today, surgeryDate: surgeryDate),
                      past: group(built.filter { $0.isPast }, today: today, surgeryDate: surgeryDate),
                      anytime: anytime)
    }

    // MARK: - Private

    // one day's rows, with late to-dos added to today
    private static func items<Plan: PlanFacts>(onDay day: Int, plan: Plan, today: Int, overdue: [Plan.ToDo]) -> [AgendaItemOf<Plan>] {
        var list: [AgendaItemOf<Plan>] = Journey.events(onDay: day, plan: plan).filter { $0.kind != .task }.map { event in
            AgendaItemOf(id: event.id, kind: event.kind, title: event.title, detail: event.detail,
                       time: event.appointment.map { DayMath.timeText(of: $0.date) } ?? "",
                       medicine: event.medicine, appointment: event.appointment)
        }
        // visits by time, the rest keep their order
        let visitSlots = list.indices.filter { list[$0].appointment != nil }
        let sortedVisits = visitSlots.map { list[$0] }.sorted { ($0.appointment?.date ?? .distantPast) < ($1.appointment?.date ?? .distantPast) }
        for (slot, visit) in zip(visitSlots, sortedVisits) { list[slot] = visit }

        for task in plan.tasks where task.dueDay == day && !(day < today && !task.isDone) {
            list.append(taskItem(task, detail: task.isDone ? "Done" : ""))
        }
        if day == today {
            let sorted = overdue.sorted { ($0.dueDay ?? 0) < ($1.dueDay ?? 0) }
            list += sorted.map { taskItem($0, detail: "Was due \(DayMath.shortDate(forDay: $0.dueDay ?? 0, from: plan.surgeryDate ?? Date()))") }
        }
        return list
    }

    private static func taskItem<Plan: PlanFacts>(_ task: Plan.ToDo, detail: String) -> AgendaItemOf<Plan> {
        AgendaItemOf(id: "task-\(task.lineID)", kind: .task, title: task.title, detail: detail,
                   isDone: task.isDone, task: task)
    }

    // today, tomorrow, then the weekday and date
    private static func dayTitle(_ day: Int, today: Int, date: Date) -> String {
        switch day - today {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return DayMath.shortDate(date)
        }
    }

    // groups days into calendar weeks
    private static func group<Plan: PlanFacts>(_ days: [AgendaDayOf<Plan>], today: Int, surgeryDate: Date) -> [AgendaWeekOf<Plan>] {
        let calendar = DayMath.calendar
        func weekStart(_ day: AgendaDayOf<Plan>) -> Int {
            let start = calendar.dateInterval(of: .weekOfYear, for: day.date)?.start ?? day.date
            return DayMath.dayOffset(of: start, from: surgeryDate)
        }
        let todayStart = weekStart(AgendaDayOf(id: today, date: DayMath.date(forDay: today, from: surgeryDate), title: "", subtitle: "",
                                             isToday: true, isPast: false, items: []))
        var order: [Int] = []
        var byWeek: [Int: [AgendaDayOf<Plan>]] = [:]
        for day in days {
            let key = weekStart(day)
            if byWeek[key] == nil { order.append(key) }
            byWeek[key, default: []].append(day)
        }
        return order.map { key in
            AgendaWeekOf(id: key, title: weekTitle(start: key, todayStart: todayStart, surgeryDate: surgeryDate), days: byWeek[key] ?? [])
        }
    }

    // this week, next week, then the date range
    private static func weekTitle(start: Int, todayStart: Int, surgeryDate: Date) -> String {
        switch (start - todayStart) / 7 {
        case 0: return "This week"
        case 1: return "Next week"
        case -1: return "Last week"
        default:
            let first = DayMath.date(forDay: start, from: surgeryDate)
            let last = DayMath.date(forDay: start + 6, from: surgeryDate)
            let parts = DayMath.calendar.dateComponents([.month], from: first, to: last)
            let sameMonth = (parts.month ?? 0) == 0 && DayMath.calendar.component(.month, from: first) == DayMath.calendar.component(.month, from: last)
            let firstText = monthDay(first)
            return sameMonth ? "\(firstText) to \(DayMath.calendar.component(.day, from: last))" : "\(firstText) to \(monthDay(last))"
        }
    }

    private static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static func upperFirst(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
