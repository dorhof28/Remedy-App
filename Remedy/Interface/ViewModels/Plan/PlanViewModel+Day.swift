//
//  PlanViewModel+Day.swift
//  Remedy
//
//  everything that happens on one picked date, for the calendar in both looks
//

import Foundation
import SwiftData

// one block on the picked day
struct DaySection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tone: Tone
    let items: [AgendaItem]
}

extension PlanViewModel {

    // the blocks of a day, most time sensitive first, empty blocks left out
    func sections(onDay picked: Int) -> [DaySection] {
        guard let plan, let surgeryDate = plan.surgeryDate else { return [] }
        let events = Journey.events(onDay: picked, plan: plan)
        let skipped = PaperCheckReport.of(plan).skipped
        var result: [DaySection] = []

        // surgery day with the hospital details
        if picked == 0 {
            var items = events.filter { $0.kind == .surgery }.map {
                AgendaItem(id: $0.id, kind: .surgery, title: $0.title, detail: $0.detail)
            }
            if let arrival = DayChecklist.arrival(for: plan) {
                items.append(AgendaItem(id: "arrival", kind: .surgery, title: "Arrive at the hospital",
                                        detail: plan.hospitalName ?? "", time: DayMath.timeText(of: arrival)))
            } else if let name = plan.hospitalName, !name.isEmpty {
                items.append(AgendaItem(id: "hospital", kind: .surgery, title: name, detail: plan.hospitalAddress ?? ""))
            }
            result.append(DaySection(id: "surgery", title: "Surgery day", symbol: "building.2", tone: .info, items: items))
        }

        // visits by time
        let visits = events.filter { $0.kind == .visit }.map { event in
            AgendaItem(id: event.id, kind: .visit, title: event.title, detail: event.detail,
                       time: event.appointment.map { DayMath.timeText(of: $0.date) } ?? "", appointment: event.appointment)
        }
        result.append(DaySection(id: "visits", title: "Visits", symbol: "stethoscope", tone: .info, items: visits))

        // medicines in the same order as the Medicines tab
        let medicines = plan.medicines.filter { $0.isConfirmed && !skipped.contains($0.persistentModelID, onDay: picked) }
        let ordered = MedicineOrder.groups(medicines.enumerated().map { index, medicine in
            MedicineOrderItem(id: index, action: medicine.action, startDay: medicine.startDay, endDay: medicine.endDay,
                              nextDue: medicine.timesOfDay.min().map { DayMath.date(forDay: picked, minute: $0, from: surgeryDate) },
                              name: MedicineText.everydayName(medicine))
        }, today: picked)
        func medicineItems(_ group: MedicineGroup) -> [AgendaItem] {
            (ordered.first { $0.group == group }?.items ?? []).map { medicineItem(medicines[$0.id], onDay: picked) }
        }
        result.append(DaySection(id: "take", title: "Take", symbol: "pills.fill", tone: .info, items: medicineItems(.takeToday)))
        result.append(DaySection(id: "dont", title: "Paused", symbol: "pause.circle", tone: .stop, items: medicineItems(.dontTake)))

        // to dos due then, and on today the late and the undated ones
        var tasks = plan.tasks.filter { $0.dueDay == picked }.map { taskItem($0, detail: $0.isDone ? "Done" : "") }
        if picked == day {
            let late = plan.tasks.filter { !$0.isDone && ($0.dueDay ?? picked) < picked }.sorted { ($0.dueDay ?? 0) < ($1.dueDay ?? 0) }
            tasks += late.map { taskItem($0, detail: "Was due \(DayMath.shortDate(forDay: $0.dueDay ?? 0, from: surgeryDate))") }
            tasks += plan.tasks.filter { !$0.isDone && $0.dueDay == nil }.map { taskItem($0, detail: "No day set") }
        }
        result.append(DaySection(id: "todo", title: "To do", symbol: "checklist", tone: .caution, items: tasks))

        // instructions in effect that day
        let rules = plan.rules.filter { !$0.isCallSign && DoseSchedule.isActive($0, on: picked) }
            .sorted { !$0.isAllowed && $1.isAllowed }
            .map { rule -> AgendaItem in
                var note = rule.condition
                if rule.startDay == picked { note = note.isEmpty ? "Starts today" : "Starts today \u{00B7} \(note)" }
                if rule.endDay == picked { note = note.isEmpty ? "Last day" : "Last day \u{00B7} \(note)" }
                var item = AgendaItem(id: "rule-\(rule.persistentModelID)", kind: .ruleChange, title: rule.title, detail: note)
                item.isAllowedRule = rule.isAllowed
                return item
            }
        result.append(DaySection(id: "rules", title: "Instructions", symbol: "figure.walk", tone: .neutral, items: rules))

        return result.filter { !$0.items.isEmpty }
    }

    // "Today · 4 days before surgery", the day card's second line
    func dayCardSubtitle(_ picked: Int) -> String {
        Self.dayCardSubtitle(picked: picked, today: day)
    }

    static func dayCardSubtitle(picked: Int, today: Int) -> String {
        let words = DayMath.surgeryWords(forDay: picked)
        return "\(daySubtitle(picked: picked, today: today)) \u{00B7} \(words.prefix(1).uppercased() + words.dropFirst())"
    }

    // MARK: - Private

    // one medicine as a row on the picked day
    private func medicineItem(_ medicine: MedicineInstruction, onDay picked: Int) -> AgendaItem {
        var parts: [String] = []
        switch medicine.action {
        case .stop:
            if medicine.startDay == picked { parts.append("Stop today") }
            if !medicine.reason.isEmpty { parts.append(medicine.reason) }
        case .takeAsNeeded:
            parts.append(medicine.onlyIf.isEmpty ? "Only when needed" : "Only for \(PlainText.lowerFirst(medicine.onlyIf))")
        default:
            parts += [medicine.amount, MedicineText.timesText(medicine)].filter { !$0.isEmpty }
        }
        if medicine.startDay == picked && medicine.action != .stop { parts.insert("Starts today", at: 0) }
        if medicine.endDay == picked { parts.append("Last day") }
        let kind: DayEventKind = medicine.action == .stop ? .stopMedicine : .startMedicine
        return AgendaItem(id: "med-\(medicine.persistentModelID)", kind: kind, title: MedicineText.everydayName(medicine),
                          detail: parts.joined(separator: " \u{00B7} "), medicine: medicine)
    }

    private func taskItem(_ task: CareTask, detail: String) -> AgendaItem {
        AgendaItem(id: "task-\(task.persistentModelID)", kind: .task, title: task.title, detail: detail,
                   isDone: task.isDone, task: task)
    }
}

// MARK: - The picked day as one list of rows

// one row on the picked day: icon tile, title, one second line, at most one trailing control
struct PlanDayRow: Identifiable {
    // what a day row opens
    enum Opens {
        case none
        case medicine(MedicineInstruction)
        case visit(Appointment)
        case task(CareTask)
        case instructions
        case checkIn
    }

    // what sits at the end of a day row
    enum Trailing: Equatable {
        case none
        case chevron
        case check(Bool)
    }

    let id: String
    let kind: ItemKind
    let title: String
    var detail: String = ""
    var detailTone: Tone = .neutral
    var isDone = false
    var opens: Opens = .none
    var trailing: Trailing = .none

    var spokenLabel: String {
        let state = isDone ? "Done" : ""
        return [title, detail, state].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

extension PlanViewModel {

    // most instruction topics shown on a day before "more"
    static let dayInstructionRows = 3

    // "Sunday, today", "Tuesday, Nov 24"
    func dayListTitle(_ picked: Int) -> String {
        let date = DayMath.date(forDay: picked, from: plan?.surgeryDate ?? now)
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let offset = picked - day
        let word: String
        switch offset {
        case 0: word = "today"
        case 1: word = "tomorrow"
        case -1: word = "yesterday"
        default: word = date.formatted(.dateTime.month(.abbreviated).day())
        }
        return "\(weekday), \(word)"
    }

    // doses and to-dos of a day, the same set Today counts
    func dayCount(onDay picked: Int) -> (done: Int, total: Int) {
        guard let plan else { return (0, 0) }
        let slots = DoseSchedule.slotsWithCheck(onDay: picked, plan: plan, now: now)
        let tasks = sections(onDay: picked).first { $0.id == "todo" }?.items ?? []
        let done = slots.filter { $0.state == .taken }.count + tasks.filter(\.isDone).count
        return (done, slots.count + tasks.count)
    }

    // "4 of 7 done" on today and past days, "7 planned" ahead, empty with nothing to count
    func dayProgressText(_ picked: Int) -> String {
        let count = dayCount(onDay: picked)
        guard count.total > 0 else { return "" }
        return picked > day ? "\(count.total) planned" : "\(count.done) of \(count.total) done"
    }

    // everything on a day as rows: surgery, visits, doses, changes, to-dos, check-in, instructions
    func dayRows(onDay picked: Int, checkedIn: Bool = false) -> [PlanDayRow] {
        guard let plan else { return [] }
        let all = changeSections(onDay: picked)
        var rows: [PlanDayRow] = []

        for item in all.first(where: { $0.id == "surgery" })?.items ?? [] {
            rows.append(PlanDayRow(id: item.id, kind: .surgery, title: item.title,
                                   detail: join(item.time, item.detail)))
        }
        for item in all.first(where: { $0.id == "visits" })?.items ?? [] {
            rows.append(PlanDayRow(id: item.id, kind: .visit, title: item.title, detail: join(item.time, item.detail),
                                   opens: item.appointment.map { .visit($0) } ?? PlanDayRow.Opens.none,
                                   trailing: item.appointment == nil ? .none : .chevron))
        }

        // doses with what was taken, on today and earlier days
        let slots = picked <= day ? DoseSchedule.slotsWithCheck(onDay: picked, plan: plan, now: now) : []
        for item in takeItems(onDay: picked) {
            guard let medicine = item.medicine else { continue }
            let mine = slots.filter { $0.medicine.persistentModelID == medicine.persistentModelID }
            let detail = mine.isEmpty ? item.detail : mine.map { Self.slotText($0) }.joined(separator: " \u{00B7} ")
            let allTaken = !mine.isEmpty && mine.allSatisfy { $0.state == .taken }
            let tone: Tone = mine.contains { $0.state == .missed } ? .stop : (allTaken ? .good : .neutral)
            rows.append(PlanDayRow(id: item.id, kind: medicine.action == .takeAsNeeded ? .asNeeded : .medicine,
                                   title: item.title, detail: detail, detailTone: tone, isDone: allTaken,
                                   opens: .medicine(medicine), trailing: .chevron))
        }

        // a medicine already listed to take that day says it starts there, so it is not listed twice
        let listed = Set(rows.compactMap { row -> PersistentIdentifier? in
            if case .medicine(let medicine) = row.opens { return medicine.persistentModelID }
            return nil
        })
        rows += changeRows(all).filter { row in
            if case .medicine(let medicine) = row.opens { return !listed.contains(medicine.persistentModelID) }
            return true
        }

        for item in all.first(where: { $0.id == "todo" })?.items ?? [] {
            rows.append(PlanDayRow(id: item.id, kind: .todo, title: item.title,
                                   detail: item.detail == "Done" ? "" : item.detail,
                                   detailTone: item.isDone ? .good : (item.task.map { PlanWording.taskIsLate($0, today: day) } == true ? .caution : .neutral),
                                   isDone: item.isDone,
                                   opens: item.task.map { .task($0) } ?? PlanDayRow.Opens.none, trailing: .check(item.isDone)))
        }

        // the daily check-in after surgery, today only
        if picked == day && day > 0 {
            rows.append(PlanDayRow(id: "checkin", kind: .checkIn, title: checkInRowTitle,
                                   detail: checkedIn ? "Done today" : "Any time", detailTone: checkedIn ? .good : .neutral, isDone: checkedIn,
                                   opens: .checkIn, trailing: .chevron))
        }

        // instructions in effect, one row per topic, the rest behind one row
        let topics = topicGroups(onDay: picked)
        for group in topics.prefix(Self.dayInstructionRows) {
            guard let first = group.rows.first else { continue }
            let more = group.rows.count - 1
            rows.append(PlanDayRow(id: "topic-\(group.id)", kind: .instruction, title: first.text,
                                   detail: join(join(first.kind.label, first.detail),
                                                more > 0 ? "+\(more) more" : ""),
                                   opens: .instructions, trailing: .chevron))
        }
        let hidden = topics.dropFirst(Self.dayInstructionRows).reduce(0) { $0 + $1.rows.count }
        if hidden > 0 {
            rows.append(PlanDayRow(id: "topic-more", kind: .instruction, title: "More instructions",
                                   detail: "\(hidden) more", opens: .instructions, trailing: .chevron))
        }
        return rows
    }

    var checkInRowTitle: String { "Daily check-in" }

    // MARK: - Papers that disagree on a day

    // a red card shows on a picked day only when its papers disagree about that day or it is the day to ask by
    func disagreementCards(onDay picked: Int) -> [PaperCheckCardData] {
        PaperCheckViewModel(plan: plan, now: now).redCards.filter { card in
            Self.disagreementAffects(day: picked, ranges: card.finding.items.map { DayRange(start: $0.startDay, end: $0.endDay) },
                                     askByDay: card.finding.askByDay)
        }
    }

    // the days from the earliest start to the latest end any paper gives, every day when none gives one
    static func disagreementAffects(day: Int, ranges: [DayRange], askByDay: Int?) -> Bool {
        if day == askByDay { return true }
        let low = ranges.compactMap(\.start).min()
        let high = ranges.compactMap(\.end).max()
        return DayRange(start: low, end: high).contains(day)
    }

    // medicine changes as rows, a stop is paused
    private func changeRows(_ sections: [DaySection]) -> [PlanDayRow] {
        (sections.first { $0.id == "changes" }?.items ?? []).map { item in
            let paused = item.kind == .stopMedicine
            let tone: Tone = paused ? .caution : (item.detail.hasPrefix("Restart") ? .good : .neutral)
            return PlanDayRow(id: item.id, kind: paused ? .paused : .medicine, title: item.title, detail: item.detail,
                              detailTone: tone,
                              opens: item.medicine.map { .medicine($0) } ?? PlanDayRow.Opens.none,
                              trailing: item.medicine == nil ? .none : .chevron)
        }
    }

    // "8:00 AM taken", "8:00 PM"
    static func slotText(_ slot: DoseSlot) -> String {
        let time = DayMath.timeText(of: slot.scheduledFor)
        switch slot.state {
        case .taken: return "\(time) taken"
        case .skipped: return "\(time) skipped"
        case .missed: return "\(time) missed"
        case .due, .upcoming: return time
        }
    }

    // a visit's detail can already start with its time, so it is said once
    func join(_ first: String, _ second: String) -> String {
        if !first.isEmpty, second.hasPrefix(first) { return second }
        return [first, second].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }
}
