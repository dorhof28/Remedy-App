//
//  PlanScreen.swift
//  Remedy
//
//  words for the redesigned plan tab (screen 39): next visit, rules now, the timeline, then more
//

import Foundation
import SwiftData

// one line on the plan list
struct PlanLine: Identifiable {
    // what tapping a plan row opens
    enum Target: Hashable {
        case none
        case day(Int)
        case visit(PersistentIdentifier)
        case task(PersistentIdentifier)
        case rule(PersistentIdentifier)
        case page(PlanPage)
        case share
        case surgery
    }

    let id: String
    let symbol: String
    var tone: Tone = .info
    let title: String
    var subtitle: String = ""
    var subtitleTone: Tone = .neutral
    var target: Target = .none

    var opens: Bool { target != .none }
}

// the next visit at the top
struct PlanNextVisit {
    let appointment: Appointment
    let title: String
    let subtitle: String
    let phoneURL: URL?
    let mapsURL: URL?
    let isInCalendar: Bool
}

// the classic plan tab: next visit, rules and the timeline
struct PlanScreen {

    let plan: CarePlan?
    let now: Date
    private let base: PlanViewModel

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        self.base = PlanViewModel(plan: plan, now: now)
    }

    // MARK: - Words

    static let title = "Plan"
    let nextEyebrow = "Next visit"
    let callButton = "Call"
    let rulesTitle = "Rules"
    let seeAllButton = "See All"
    let timelineTitle = "Timeline"
    let tasksTitle = "To-dos"
    let moreTitle = "More"
    let emptyTitle = "No Plan Yet"
    let emptyText = "Scan your papers and add your surgery date to see your plan."
    let addPapersButton = "Add Papers"

    var hasPlan: Bool { base.hasPlan }
    var today: Int { base.day }
    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    // MARK: - Next visit

    var nextVisit: PlanNextVisit? {
        guard let row = base.visitRows.first else { return nil }
        let visit = row.appointment
        var parts = [DayMath.shortDate(visit.date), DayMath.timeText(of: visit.date)]
        if !visit.place.isEmpty { parts.append(visit.place) }
        let details = AppointmentDetailViewModel(appointment: visit, now: now)
        return PlanNextVisit(appointment: visit, title: visit.title, subtitle: parts.joined(separator: " \u{00B7} "),
                             phoneURL: details.phoneURL, mapsURL: details.mapsURL, isInCalendar: visit.isInCalendar)
    }

    // MARK: - Rules

    // rules in effect now, not allowed first, at most three
    var ruleLines: [PlanLine] {
        Array(base.activeRuleRows(onDay: today).prefix(3)).map { Self.ruleLine($0) }
    }

    static func ruleLine(_ row: RuleRow) -> PlanLine {
        let allowed = row.rule.isAllowed
        return PlanLine(id: "rule-\(row.id.hashValue)", symbol: allowed ? "checkmark.circle" : "nosign",
                        tone: allowed ? .good : .stop, title: row.title,
                        subtitle: RuleRow.reminderDetail(detail: row.detail, headline: row.headline),
                        target: .rule(row.id))
    }

    // MARK: - Timeline

    // every key day, today with its day number, a day opens that day
    var timelineLines: [PlanLine] {
        guard let plan else { return [] }
        return Journey.stops(plan: plan, today: today).map { stop in
            let date = DayMath.shortDate(stop.date)
            if stop.state == .today {
                return PlanLine(id: "day-\(stop.day)", symbol: "sun.max", title: todayTitle(stop.day),
                                subtitle: date, target: .day(stop.day))
            }
            let events = Journey.events(onDay: stop.day, plan: plan)
            let first = events.first
            let title = stop.day == 0 ? "Surgery" : (first?.title ?? stop.titles.first ?? "")
            var subtitle = date
            if let visit = first?.appointment { subtitle += " \u{00B7} " + DayMath.timeText(of: visit.date) }
            if events.count > 1, stop.day != 0 { subtitle += " \u{00B7} \(events.count - 1) more" }
            let done = stop.state == .done
            return PlanLine(id: "day-\(stop.day)", symbol: done ? "checkmark.circle" : Self.symbol(first?.kind),
                            tone: done ? .good : Self.tone(first?.kind), title: title, subtitle: subtitle,
                            target: .day(stop.day))
        }
    }

    // "Today · day 3" after surgery, "Today" before
    func todayTitle(_ day: Int) -> String {
        day > 0 ? "Today \u{00B7} day \(day)" : "Today"
    }

    static func symbol(_ kind: DayEventKind?) -> String {
        switch kind {
        case .surgery: return "bed.double"
        case .stopMedicine: return "nosign"
        case .visit: return "calendar"
        case .task: return "checklist"
        case .ruleChange: return "figure.walk"
        case .startMedicine, .endMedicine: return "pills"
        case nil: return "calendar"
        }
    }

    static func tone(_ kind: DayEventKind?) -> Tone {
        kind == .stopMedicine ? .stop : .info
    }

    // MARK: - To-dos

    var taskLines: [PlanLine] {
        base.taskRows.map { row in
            PlanLine(id: "task-\(row.id.hashValue)", symbol: row.isDone ? "checkmark.circle" : "circle",
                     tone: row.isDone ? .good : .info, title: row.title, subtitle: row.detail,
                     subtitleTone: row.detailTone, target: .task(row.id))
        }
    }

    // MARK: - More

    var moreLines: [PlanLine] {
        let papers = plan?.papers.count ?? 0
        let paperWord = papers == 1 ? "1 paper" : "\(papers) papers"
        var lines = [
            PlanLine(id: "checkIns", symbol: "heart", title: "Check-ins", subtitle: "Pain and photos of the cut",
                     target: .page(.checkIns)),
            PlanLine(id: "papers", symbol: "doc.text", title: "Papers", subtitle: paperWord, target: .page(.papers)),
            PlanLine(id: "surgery", symbol: "bed.double", title: "Your surgery", subtitle: surgerySubtitle,
                     target: .surgery)
        ]
        lines.append(PlanLine(id: "share", symbol: "square.and.arrow.up", title: "Share or Print Plan", target: .share))
        return lines
    }

    private var surgerySubtitle: String {
        guard let date = plan?.surgeryDate else { return "" }
        return "\(DayMath.shortDate(date)) \u{00B7} hospital and times"
    }
}
