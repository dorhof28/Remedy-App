//
//  TodayViewModel.swift
//  Remedy
//
//  today screen for both looks
//

import Foundation
import SwiftData

struct TodayViewModel {

    let plan: CarePlan?
    let now: Date

    // today as a plan day
    let day: Int
    let layout: TodayLayout

    // today's set-time doses worked out once
    private let todaySlots: [DoseSlot]

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now

        if let plan, let today = DoseSchedule.today(for: plan, now: now) {
            day = today
            switch SurgeryPhase.forDay(today) {
            case .beforeSurgery: layout = .beforeSurgery
            case .surgeryDay: layout = .surgeryDay
            case .afterSurgery: layout = .afterSurgery
            }
            todaySlots = DoseSchedule.slots(onDay: today, plan: plan, now: now)
        } else {
            day = 0
            layout = plan == nil ? .noPlan : .needsSurgeryDate
            todaySlots = []
        }
    }

    // MARK: - Shortcuts

    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    // only medicines the patient confirmed
    private var medicines: [MedicineInstruction] {
        plan?.medicines.filter { $0.isConfirmed } ?? []
    }

    // MARK: - Header ("Surgery in 4 days")

    var headerTitle: String {
        switch layout {
        case .beforeSurgery: return "Surgery \(DayMath.relative(daysFromToday: -day))"   // "Surgery in 4 days"
        case .surgeryDay: return "Surgery day"
        case .afterSurgery: return "Day \(day) of recovery"
        case .noPlan, .needsSurgeryDate: return ""
        }
    }

    // "Thursday October 29 · Knee replacement"
    var headerDetail: String {
        let procedure = plan?.procedure ?? ""
        let when: String
        switch layout {
        case .beforeSurgery: when = DayMath.longDate(surgeryDate)
        case .afterSurgery: when = "Surgery was \(DayMath.shortDate(surgeryDate))"
        default: when = ""
        }
        return [when, procedure].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // header + top card as one text for "Read to me" in the Simple look
    var spokenSummary: String {
        let card = layout == .afterSurgery ? nowCard.spokenLabel : beforeTopCard.spokenLabel
        return "\(headerTitle). \(card)"
    }

    var headerSymbol: String {
        switch layout {
        case .afterSurgery: return "figure.walk"
        case .surgeryDay: return "cross.case.fill"
        default: return "calendar"
        }
    }

    // MARK: - Asking for the surgery date

    let surgeryDatePrompt = "When is your surgery?"
    let surgeryDateExplanation = "Your papers count days from your surgery (\u{201C}7 days before\u{201D}). Add the date and Remedy will turn them into real dates."

    // saves the date from the prompt
    func saveSurgeryDate(_ date: Date, in context: ModelContext) {
        guard let plan else { return }
        PlanActions.setSurgeryDate(date, on: plan, in: context)
    }

    // MARK: - Before surgery: the top card

    // stop instructions that begin today
    private var stopsStartingToday: [MedicineInstruction] {
        medicines.filter { $0.action == .stop && $0.startDay == day }
    }

    // stops in effect today that began on an earlier day
    private var stopsAlreadyInEffect: [MedicineInstruction] {
        medicines.filter { $0.action == .stop && $0.startDay != day && DoseSchedule.isActive($0, on: day) }
    }

    // stops that begin on a later day grouped by that day soonest first
    private var futureStopDays: [(day: Int, medicines: [MedicineInstruction])] {
        let future = medicines.filter { $0.action == .stop && ($0.startDay ?? Int.min) > day }
        let grouped = Dictionary(grouping: future) { $0.startDay ?? 0 }
        return grouped.keys.sorted().map { (day: $0, medicines: grouped[$0] ?? []) }
    }

    var beforeTopCard: BeforeTopCard {
        // 1 something to stop today the most important thing on the screen
        let stops = stopsStartingToday
        if !stops.isEmpty {
            let one = stops.count == 1
            return BeforeTopCard(
                kind: .stopToday,
                symbol: "exclamationmark.circle.fill",
                tone: .stop,
                eyebrow: "Today",
                title: one ? "Stop taking this today" : "Stop taking these today",
                names: stops.map { MedicineText.everydayName($0) },
                nameSymbol: "nosign",
                detail: stops.first { !$0.reason.isEmpty }?.reason ?? "",
                buttonTitle: one ? "I\u{2019}ve put it away" : "I\u{2019}ve put them away",
                isDone: stops.allSatisfy { $0.putAwayAt != nil },
                doneText: "Put away. Don\u{2019}t take \(one ? "it" : "them") until your surgeon says it\u{2019}s OK."
            )
        }

        // 2 surgery day
        if layout == .surgeryDay {
            return BeforeTopCard(
                kind: .surgeryDay,
                symbol: "heart.fill",
                tone: .info,
                eyebrow: "Today",
                title: "Today is your surgery",
                names: [],
                nameSymbol: "",
                detail: "Follow your care team\u{2019}s instructions today. Remedy picks up again tomorrow with your recovery plan.",
                buttonTitle: nil,
                isDone: false,
                doneText: ""
            )
        }

        // 3 nothing today show the next change with its real date
        if let next = futureStopDays.first {
            return BeforeTopCard(
                kind: .nextStop,
                symbol: "calendar.badge.clock",
                tone: .caution,
                eyebrow: "Nothing to stop today",
                title: "Next: stop on \(DayMath.shortDate(forDay: next.day, from: surgeryDate))",
                names: next.medicines.map { MedicineText.everydayName($0) },
                nameSymbol: "nosign",
                detail: "\(DayMath.relative(daysFromToday: next.day - day).capitalizedFirst), \(DayMath.surgeryWords(forDay: next.day)).",
                buttonTitle: nil,
                isDone: false,
                doneText: ""
            )
        }

        // 4 everything is already stopped
        return BeforeTopCard(
            kind: .allClear,
            symbol: "checkmark.circle.fill",
            tone: .good,
            eyebrow: "Today",
            title: "Nothing new to stop",
            names: [],
            nameSymbol: "",
            detail: "Keep not taking the medicines on hold below.",
            buttonTitle: nil,
            isDone: false,
            doneText: ""
        )
    }

    // MARK: - Before surgery: on hold ("Don't take")

    private var onHoldRows: [TodayRow] {
        stopsAlreadyInEffect.map { medicine in
            var detail = "Since \(DayMath.shortDate(forDay: medicine.startDay ?? day, from: surgeryDate))"
            if let end = medicine.endDay {
                detail += " · until \(DayMath.shortDate(forDay: end, from: surgeryDate))"
            }
            return TodayRow(id: medicine.name + "-hold", symbol: "nosign", tone: .stop,
                            title: MedicineText.everydayName(medicine), detail: detail)
        }
    }

    var showsOnHold: Bool { !onHoldRows.isEmpty }
    var onHoldTitle: String { "Don\u{2019}t take (\(onHoldRows.count))" }

    // at most 4 rows so Today doesn't scroll
    var onHoldVisibleRows: [TodayRow] {
        onHoldRows.count <= 4 ? onHoldRows : Array(onHoldRows.prefix(3))
    }

    var onHoldMoreText: String {
        let hidden = onHoldRows.count - onHoldVisibleRows.count
        return hidden > 0 ? "and \(hidden) more in Medicines" : ""
    }

    // MARK: - Before surgery: coming up

    // the next two stop days
    var comingUpRows: [TodayRow] {
        let skipFirst = beforeTopCard.kind == .nextStop
        return futureStopDays.dropFirst(skipFirst ? 1 : 0).prefix(2).map { entry in
            let names = entry.medicines.map { MedicineText.everydayName($0) }
            let date = DayMath.shortDate(forDay: entry.day, from: surgeryDate)
            let relative = DayMath.relative(daysFromToday: entry.day - day)
            return TodayRow(id: "stop\(entry.day)", symbol: "calendar", tone: .caution,
                            title: "Stop \(PlainText.list(names))", detail: "\(date) · \(relative)")
        }
    }

    var showsComingUp: Bool { !comingUpRows.isEmpty }
    let comingUpTitle = "Coming up"

    // MARK: - Before surgery: OK to take

    var okToTakeRows: [TodayRow] {
        medicines
            .filter { $0.action == .okToTake && DoseSchedule.isActive($0, on: day) }
            .map { medicine in
                let detail = medicine.onlyIf.isEmpty ? "OK to take" : "If \(PlainText.lowerFirst(medicine.onlyIf))"
                return TodayRow(id: medicine.name + "-ok", symbol: "checkmark", tone: .good,
                                title: MedicineText.everydayName(medicine), detail: detail)
            }
    }

    var showsOkToTake: Bool { !okToTakeRows.isEmpty }
    let okToTakeTitle = "OK to take"

    // MARK: - To-dos (both phases)

    // before surgery every before-surgery to-do
    var taskRows: [TaskRow] {
        guard let plan else { return [] }
        let todayStart = DayMath.calendar.startOfDay(for: now)

        let shown = plan.tasks.filter { task in
            if task.isDone { return (task.doneAt ?? .distantPast) >= todayStart }
            if layout == .afterSurgery { return PlanWording.isOnToday(task, today: day) }
            return task.paper == .beforeSurgery
        }

        return shown
            .sorted { ($0.dueDay ?? Int.max) < ($1.dueDay ?? Int.max) }
            .prefix(3)
            .map { task in
                TaskRow(task: task,
                        title: task.title,
                        detail: PlanWording.taskDueText(task, today: day, surgeryDate: surgeryDate),
                        isDone: task.isDone)
            }
    }

    var showsTasks: Bool { !taskRows.isEmpty }
    let tasksTitle = "To do"

    // MARK: - After surgery: the dose card

    var nowCard: NowDoseCard {
        guard !todaySlots.isEmpty else {
            return NowDoseCard(kind: .noDoses, symbol: "pills", tone: .neutral, eyebrow: "Medicines",
                               title: "No set-time medicines today", detail: "", lines: [], slots: [])
        }

        // due now first then the latest missed one then the next one
        if let due = todaySlots.first(where: { $0.state == .due }) {
            let group = sameTime(as: due)
            return card(.due, group: group, symbol: "bell.fill", tone: .info,
                        eyebrow: "Due now · \(DayMath.timeText(of: due.scheduledFor))", detail: "")
        }
        if let missed = todaySlots.last(where: { $0.state == .missed }) {
            let group = sameTime(as: missed)
            return card(.missed, group: group, symbol: "exclamationmark.circle.fill", tone: .stop,
                        eyebrow: "Missed · \(DayMath.timeText(of: missed.scheduledFor))",
                        detail: "If you took it, tap I took it. If not, check your papers or call your care team before taking it late.")
        }
        if let next = todaySlots.first(where: { $0.state == .upcoming }) {
            let group = sameTime(as: next)
            let minutes = max(0, Int(next.scheduledFor.timeIntervalSince(now) / 60))
            return card(.next, group: group, symbol: "clock", tone: .info,
                        eyebrow: "Next · \(DayMath.timeText(of: next.scheduledFor))",
                        detail: "In \(DayMath.duration(minutes: minutes))")
        }
        return NowDoseCard(kind: .allDone, symbol: "checkmark.circle.fill", tone: .good, eyebrow: "Medicines",
                           title: "All done for today", detail: "Nothing else is due today.", lines: [], slots: [])
    }

    // every dose at the same time and in the same state
    private func sameTime(as slot: DoseSlot) -> [DoseSlot] {
        todaySlots.filter { $0.scheduledFor == slot.scheduledFor && $0.state == slot.state }
    }

    private func card(_ kind: NowDoseCard.Kind, group: [DoseSlot], symbol: String, tone: Tone,
                      eyebrow: String, detail: String) -> NowDoseCard {
        let lines = group.map { slot in
            DoseLine(id: slot.id,
                     name: MedicineText.fullName(slot.medicine),
                     how: MedicineText.howText(slot.medicine),
                     pillShape: slot.medicine.pillShape,
                     pillColor: slot.medicine.pillColor)
        }
        let title = group.count == 1 ? (lines.first?.name ?? "") : "\(group.count) medicines"
        return NowDoseCard(kind: kind, symbol: symbol, tone: tone, eyebrow: eyebrow,
                           title: title, detail: detail, lines: lines, slots: group)
    }

    let takeButtonTitle = "I took it"
    let skipButtonTitle = "Skip"

    // MARK: - After surgery: progress + the full list

    var doseProgress: DoseProgress {
        let taken = todaySlots.filter { $0.state == .taken }.count
        let missed = todaySlots.filter { $0.state == .missed }.count
        return DoseProgress(
            taken: taken,
            total: todaySlots.count,
            text: "\(taken) of \(todaySlots.count) taken today",
            detail: missed > 0 ? "\(missed) missed" : "",
            tone: missed > 0 ? .stop : (taken == todaySlots.count ? .good : .info)
        )
    }

    var showsDoseProgress: Bool { !todaySlots.isEmpty }
    let doseListTitle = "Today\u{2019}s doses"

    // the sheet doses grouped into morning afternoon and evening
    var doseSections: [DoseSection] {
        DayPeriod.allCases.compactMap { period in
            let rows = todaySlots
                .filter { DayPeriod.forMinute($0.minute) == period }
                .map { listRow(for: $0) }
            return rows.isEmpty ? nil : DoseSection(period: period, title: period.title, rows: rows)
        }
    }

    private func listRow(for slot: DoseSlot) -> DoseListRow {
        let stateText: String
        let tone: Tone
        switch slot.state {
        case .taken:
            stateText = "Taken at \(DayMath.timeText(of: slot.log?.loggedAt ?? slot.scheduledFor))"
            tone = .good
        case .skipped:
            stateText = "Skipped"
            tone = .neutral
        case .missed:
            stateText = "Missed"
            tone = .stop
        case .due:
            stateText = "Due now"
            tone = .info
        case .upcoming:
            stateText = "Later"
            tone = .neutral
        }
        return DoseListRow(slot: slot,
                           timeText: DayMath.timeText(slot.minute),
                           name: MedicineText.fullName(slot.medicine),
                           how: MedicineText.howText(slot.medicine),
                           stateText: stateText,
                           tone: tone)
    }

    // MARK: - After surgery: only when needed

    var asNeededRows: [AsNeededRow] {
        medicines
            .filter { $0.action == .takeAsNeeded && DoseSchedule.isActive($0, on: day) }
            .map { medicine in
                let status = DoseSchedule.asNeededStatus(for: medicine, now: now)

                let statusText: String
                let tone: Tone
                if status.reachedMax {
                    statusText = "No more today (\(status.takenToday) of \(medicine.maxPerDay ?? status.takenToday))"
                    tone = .stop
                } else if let next = status.nextAllowed {
                    statusText = "Next one OK at \(DayMath.timeText(of: next))"
                    tone = .caution
                } else {
                    statusText = "Can take one now, if needed"
                    tone = .good
                }

                var details: [String] = []
                if !medicine.onlyIf.isEmpty { details.append("Only for \(PlainText.lowerFirst(medicine.onlyIf))") }
                if let last = status.lastTaken { details.append("Last at \(DayMath.timeText(of: last))") }

                return AsNeededRow(medicine: medicine,
                                   name: MedicineText.fullName(medicine),
                                   status: statusText,
                                   detail: details.joined(separator: " · "),
                                   tone: tone,
                                   canTake: status.canTakeNow,
                                   buttonTitle: "I took one")
            }
    }

    var showsAsNeeded: Bool { !asNeededRows.isEmpty }
    let asNeededTitle = "Only when needed"

    // MARK: - After surgery: daily goals

    var goalTiles: [GoalTile] {
        (plan?.goals ?? [])
            .filter { DoseSchedule.isActive($0, on: day) }
            .map { goal in
                let count = DoseSchedule.goalCount(goal, now: now)
                return GoalTile(goal: goal,
                                title: goal.title,
                                symbol: goal.symbol,
                                count: count,
                                target: goal.target,
                                countText: "\(min(count, goal.target)) of \(goal.target)",
                                isComplete: count >= goal.target)
            }
    }

    var showsGoals: Bool { !goalTiles.isEmpty }
    let goalsTitle = "Daily goals"
    let goalsHint = "Tap to add one. Touch and hold to take one back."

    // MARK: - After surgery: not allowed yet

    var notYetRows: [TodayRow] {
        (plan?.rules ?? [])
            .filter { !$0.isAllowed && DoseSchedule.isActive($0, on: day) }
            .prefix(3)
            .map { rule in
                let status = PlanWording.ruleStatus(rule, today: day, surgeryDate: surgeryDate)
                return TodayRow(id: rule.title + "-rule", symbol: "hand.raised.fill", tone: .caution,
                                title: rule.title, detail: status.detail)
            }
    }

    var showsNotYet: Bool { !notYetRows.isEmpty }
    let notYetTitle = "Not yet"

    // MARK: - Actions (each returns what the Undo bar needs)

    // "I've put them away" on the before-surgery card
    func putAwayStopsToday(in context: ModelContext) -> TodayUndo? {
        let stops = stopsStartingToday.filter { $0.putAwayAt == nil }
        guard !stops.isEmpty else { return nil }
        MedicineActions.markPutAway(stops, now: now, in: context)
        return TodayUndo(message: "Marked as put away") { context in
            MedicineActions.clearPutAway(stops, in: context)
        }
    }

    // "I took it" on the dose card logs every medicine in the card
    func takeNow(in context: ModelContext) -> TodayUndo? {
        logNowCard(as: .taken, message: "Marked as taken", in: context)
    }

    // "Skip" on the dose card
    func skipNow(in context: ModelContext) -> TodayUndo? {
        logNowCard(as: .skipped, message: "Marked as skipped", in: context)
    }

    private func logNowCard(as status: DoseStatus, message: String, in context: ModelContext) -> TodayUndo? {
        let card = nowCard
        guard card.showsButtons else { return nil }
        let undos = card.slots.map { slot in
            DoseActions.log(slot.medicine, scheduledFor: slot.scheduledFor, as: status, now: now, in: context)
        }
        return TodayUndo(message: message) { context in
            undos.forEach { DoseActions.undo($0, in: context) }
        }
    }

    // ticks a dose in the list
    func toggle(_ row: DoseListRow, in context: ModelContext) -> TodayUndo? {
        let slot = row.slot
        if let log = slot.log {
            let previous = log.status
            DoseActions.remove(log, in: context)
            return TodayUndo(message: "Removed") { [now] context in
                DoseActions.log(slot.medicine, scheduledFor: slot.scheduledFor, as: previous, now: now, in: context)
            }
        }
        let undo = DoseActions.log(slot.medicine, scheduledFor: slot.scheduledFor, as: .taken, now: now, in: context)
        return TodayUndo(message: "Marked as taken") { context in
            DoseActions.undo(undo, in: context)
        }
    }

    // "I took one" for an only-when-needed medicine
    func takeAsNeeded(_ row: AsNeededRow, in context: ModelContext) -> TodayUndo? {
        guard row.canTake else { return nil }
        let undo = DoseActions.logAsNeeded(row.medicine, now: now, in: context)
        return TodayUndo(message: "Logged one \(row.medicine.name)") { context in
            DoseActions.undo(undo, in: context)
        }
    }

    // tap a to-do ticks it on or off
    func toggle(_ row: TaskRow, in context: ModelContext) -> TodayUndo? {
        let task = row.task
        let wasDone = task.isDone
        let previousDoneAt = task.doneAt
        TaskActions.toggle(task, now: now, in: context)
        return TodayUndo(message: wasDone ? "Marked as not done" : "Marked as done") { context in
            TaskActions.setDone(wasDone, for: task, now: previousDoneAt ?? Date(), in: context)
        }
    }

    // tap a goal tile +1
    func addOne(to tile: GoalTile, in context: ModelContext) {
        GoalActions.addOne(to: tile.goal, now: now, in: context)
    }

    // touch and hold a goal tile take one back
    func removeOne(from tile: GoalTile, in context: ModelContext) {
        GoalActions.removeOne(from: tile.goal, now: now, in: context)
    }
}

// MARK: - Small helpers

extension DayPeriod {
    // "Morning" for section headers
    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
