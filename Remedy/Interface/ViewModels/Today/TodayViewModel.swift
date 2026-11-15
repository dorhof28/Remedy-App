//
//  TodayViewModel.swift
//  Remedy
//
//  today screen for both looks
//

import Foundation
import SwiftData

// today on the plan: doses, visits, to-dos, rules and goals, shared by both looks
struct TodayViewModel {

    let plan: CarePlan?
    let now: Date

    // today as a plan day
    let day: Int
    let layout: TodayLayout

    // today's set-time doses worked out once
    let todaySlots: [DoseSlot]

    // the paper check worked out once, not on every read
    let paperReport: PaperCheckReport?

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        self.paperReport = plan.map { PaperCheckReport.of($0) }

        if let plan, let today = DoseSchedule.today(for: plan, now: now) {
            day = today
            switch SurgeryPhase.forDay(today) {
            case .beforeSurgery: layout = .beforeSurgery
            case .surgeryDay: layout = .surgeryDay
            case .afterSurgery: layout = .afterSurgery
            }
            todaySlots = DoseSchedule.slotsWithCheck(onDay: today, plan: plan, now: now)
        } else {
            day = 0
            layout = plan == nil ? .noPlan : .needsSurgeryDate
            todaySlots = []
        }
    }

    // MARK: - Shortcuts

    var surgeryDate: Date { plan?.surgeryDate ?? now }

    // only medicines the patient confirmed and not replaced on the day they show for
    var medicines: [MedicineInstruction] {
        guard let plan else { return [] }
        let skipped = paperReport?.skipped ?? SkippedLines()
        // a line starting later shows as coming up so it is checked on its first day
        return plan.medicines.filter {
            $0.isConfirmed && !skipped.contains($0.persistentModelID, onDay: max(day, $0.startDay ?? day))
        }
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

    // header + top card as one text for "Read to me" in the Simple look
    var spokenSummary: String {
        let card = layout == .afterSurgery ? nowCard.spokenLabel : beforeTopCard.spokenLabel
        return "\(headerTitle). \(card)"
    }

    // MARK: - Busy day checklist

    // what is due today when it is a busy day
    var checklist: [ChecklistItem] {
        guard let plan, layout != .noPlan, layout != .needsSurgeryDate, DayChecklist.isBusy(day: day, plan: plan, skipped: paperReport?.skipped ?? SkippedLines()) else { return [] }
        return DayChecklist.items(plan: plan, day: day, now: now, checked: ChecklistStore.checked(now: now),
                                  skipped: paperReport?.skipped ?? SkippedLines())
    }

    // flips what is saved for a line, not what is shown, so a line the clock ticked cannot get stuck
    static func flipSaved(_ id: String, now: Date) {
        let saved = ChecklistStore.checked(now: now).contains(id)
        ChecklistStore.setChecked(id, !saved, now: now)
    }

    // ticks one item and updates the Live Activity
    func toggleChecklist(_ item: ChecklistItem, in context: ModelContext) {
        // a line the clock ticks has nothing to toggle
        guard !item.isAutomatic else { return }
        if item.id.hasPrefix("task-"), let plan, let task = plan.tasks.first(where: { DayChecklist.taskID($0, in: plan) == item.id }) {
            task.isDone.toggle()
            task.doneAt = task.isDone ? now : nil
            context.saveNow()
        } else {
            Self.flipSaved(item.id, now: now)
        }
        let plan = plan
        let now = now
        Task { await LiveActivityManager.sync(plan: plan, now: now) }
    }

    // MARK: - Asking for the surgery date

    let surgeryDatePrompt = "When is your surgery?"
    // 92 words
    let surgeryDateEyebrow = "One question first"
    let surgeryDateWhy = "Every date in your plan counts from your surgery day. Your papers don\u{2019}t say it."

    // saves the date from the prompt
    func saveSurgeryDate(_ date: Date, in context: ModelContext) {
        guard let plan else { return }
        PlanActions.setSurgeryDate(date, on: plan, in: context)
    }

    // MARK: - Before surgery: the top card

    // stop instructions that begin today
    var stopsStartingToday: [MedicineInstruction] {
        medicines.filter { $0.action == .stop && $0.startDay == day }
    }

    // stops in effect today that began on an earlier day
    var stopsAlreadyInEffect: [MedicineInstruction] {
        medicines.filter { $0.action == .stop && $0.startDay != day && DoseSchedule.isActive($0, on: day) }
    }

    // stops that begin on a later day grouped by that day soonest first
    var futureStopDays: [(day: Int, medicines: [MedicineInstruction])] {
        let future = medicines.filter { $0.action == .stop && ($0.startDay ?? Int.min) > day }
        let grouped = Dictionary(grouping: future) { $0.startDay ?? 0 }
        return grouped.keys.sorted().map { (day: $0, medicines: grouped[$0] ?? []) }
    }

    // the next day something stops, for the header and the simple tiles
    var nextStop: (dateText: String, daysAway: Int, names: [String])? {
        guard let next = futureStopDays.first else { return nil }
        return (DayMath.shortDate(forDay: next.day, from: surgeryDate), next.day - day,
                Self.uniqueNames(next.medicines.map { MedicineText.everydayName($0) }))
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
                names: Self.uniqueNames(stops.map { MedicineText.everydayName($0) }),
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
                names: Self.uniqueNames(next.medicines.map { MedicineText.everydayName($0) }),
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

    // MARK: - Before surgery: coming up

    // the next two stop days
    var comingUpRows: [TodayRow] {
        // the very next stop is the top card's, this lists the ones after it
        return futureStopDays.dropFirst().prefix(2).map { entry in
            let names = entry.medicines.map { MedicineText.everydayName($0) }
            let date = DayMath.shortDate(forDay: entry.day, from: surgeryDate)
            let relative = DayMath.relative(daysFromToday: entry.day - day)
            return TodayRow(id: "stop\(entry.day)", symbol: "calendar", tone: .caution,
                            title: "Stop \(PlainText.list(names))", detail: "\(date) · \(relative)")
        }
    }

    var showsComingUp: Bool { !comingUpRows.isEmpty }
    let comingUpTitle = "Coming up"

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
                        isDone: task.isDone, isLate: PlanWording.taskIsLate(task, today: day))
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


    // MARK: - After surgery: progress + the full list

    var showsDoseProgress: Bool { !todaySlots.isEmpty }

    // the sheet doses grouped into morning afternoon and evening
    var doseSections: [DoseSection] {
        DayPeriod.allCases.compactMap { period in
            let rows = todaySlots
                .filter { DayPeriod.forMinute($0.minute) == period }
                .map { listRow(for: $0) }
            return rows.isEmpty ? nil : DoseSection(period: period, title: period.title, rows: rows)
        }
    }

    // one dose as a today row with its state words and color
    func listRow(for slot: DoseSlot) -> DoseListRow {
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
                let target = GoalCounts.dailyTarget(timesPerDay: goal.timesPerDay, target: goal.target)
                return GoalTile(goal: goal,
                                title: goal.title,
                                symbol: goal.symbol,
                                count: count,
                                target: target,
                                countText: GoalCounts.countText(done: count, target: target),
                                isComplete: GoalCounts.isComplete(done: count, target: target),
                                amountText: GoalCounts.amountText(reps: goal.reps, sets: goal.sets, seconds: goal.seconds),
                                buttonTitle: GoalCounts.buttonText(done: count, target: target))
            }
    }

    // a goal with a time on it, nil for most
    func goalMinute(_ tile: GoalTile) -> Int? {
        DayOrder.goalMinute(title: tile.goal.title, detail: tile.goal.detail, quote: tile.goal.quote)
    }


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

    // daily check in, only after surgery
    var checkIn: CheckInViewModel { CheckInViewModel(plan: plan, now: now) }
    var showsCheckIn: Bool { layout == .afterSurgery && checkIn.isAvailable }

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

    // the soft question on a stop day, empty when the setting is off
    func stopQuestions(defaults: UserDefaults = .standard) -> [StopQuestion] {
        guard LastDoseQuestion.isOn(defaults), layout == .beforeSurgery else { return [] }
        let url = LastDoseQuestion.officeURL(plan: plan)
        let skipped = paperReport?.skipped ?? SkippedLines()
        return stopsStartingToday.filter { !skipped.contains($0.persistentModelID, onDay: day) }.map { medicine in
            let answer = LastDoseQuestion.answer(of: medicine)
            return StopQuestion(medicine: medicine,
                                question: LastDoseQuestion.text(for: medicine),
                                answer: answer,
                                followUp: answer == .yes ? LastDoseQuestion.yesFollowUp
                                    : (answer == .no ? LastDoseQuestion.noFollowUp : ""),
                                callURL: url)
        }
    }

    // saves yes or no and can put it back
    func answerLastDose(_ answer: LastDoseAnswer, for question: StopQuestion, in context: ModelContext) -> TodayUndo? {
        let medicine = question.medicine
        let previous = LastDoseQuestion.answer(of: medicine)
        let previousAt = medicine.lastTakenAt
        MedicineActions.setLastTaken(answer, on: medicine, now: now, in: context)
        return TodayUndo(message: "Answer saved") { context in
            medicine.lastTakenAnswer = previous?.rawValue
            medicine.lastTakenAt = previousAt
            context.saveNow()
        }
    }

    // "I took it" on the dose card logs every medicine in the card
    func takeNow(in context: ModelContext) -> TodayUndo? {
        logNowCard(as: .taken, message: "Marked as taken", in: context)
    }

    // logs every dose on the now card at once and returns one undo
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

    // skips one dose in the list
    func skip(_ row: DoseListRow, in context: ModelContext) -> TodayUndo? {
        let slot = row.slot
        let undo = DoseActions.log(slot.medicine, scheduledFor: slot.scheduledFor, as: .skipped, now: now, in: context)
        return TodayUndo(message: "Marked as skipped") { context in
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

extension TodayViewModel {
    // same medicine named on two papers shows once
    static func uniqueNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0.lowercased()).inserted }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
