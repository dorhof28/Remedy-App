//
//  SimpleHome+ViewModels.swift
//  Remedy
//
//  what simple home and my day show: one thing to do now, the next two, and the whole day as instructions
//

import Foundation
import SwiftData

// MARK: - One thing to do

// one card in my day and one row on home, phrased as an instruction like "Take 1 Tylenol"
struct SimpleDayItem: Identifiable {
    enum Kind: Equatable { case dose, asNeeded, visit, todo, checkIn, goal, stop, fillIn, surgery, rule }
    enum State: Equatable { case now, late, anyTime, later, done }

    let id: String
    let kind: Kind
    let state: State
    let sortDate: Date
    // "8:00 PM", "Any time today", "Missed · 2:00 PM", "Done · 8:03 AM"
    let whenText: String
    let title: String
    var detail: String = ""
    // the one trailing button in my day, nil when there is nothing to tap
    var buttonTitle: String? = nil
    var doses: [DoseListRow] = []
    var task: TaskRow? = nil
    var goal: GoalTile? = nil
    var asNeeded: AsNeededRow? = nil
    var appointment: Appointment? = nil
    // the items folded into this one, doses due together
    var members: [String] = []
    // the screen a tap on the card opens
    var medicine: MedicineInstruction? { doses.first?.slot.medicine ?? asNeeded?.medicine }

    var isDone: Bool { state == .done }

    var spokenLabel: String {
        [whenText, title, detail].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// MARK: - Instruction words

// plain instructions like take 1 tylenol
enum SimpleInstruction {

    // "Take 1 Tylenol" from "1 tablet", "Take Tylenol" when the amount is not a count of pills
    static func take(name: String, amount: String) -> String {
        let pattern = #"^\s*(\d+(?:[./]\d+)?|one|two|half)\s+(tablets?|tabs?|capsules?|caps?|pills?|puffs?|drops?|patch(?:es)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: amount, range: NSRange(amount.startIndex..., in: amount)),
              let range = Range(match.range(at: 1), in: amount) else {
            return "Take \(name)"
        }
        let words = ["one": "1", "two": "2", "half": "1/2"]
        let count = String(amount[range])
        return "Take \(words[count.lowercased()] ?? count) \(name)"
    }

    // the name people say: the brand when the paper gives one, else the name without the strength
    static func everydayName(name: String, alsoKnownAs: [String], isGroup: Bool) -> String {
        let own = name.lowercased()
        if !isGroup, let brand = alsoKnownAs.first(where: { !$0.isEmpty && !own.contains($0.lowercased()) }) {
            return brand.prefix(1).uppercased() + brand.dropFirst()
        }
        return TodayViewModel.shortName(name)
    }

    static func everydayName(_ medicine: MedicineInstruction) -> String {
        everydayName(name: medicine.name, alsoKnownAs: medicine.alsoKnownAs, isGroup: medicine.isGroup)
    }

    // "500 mg · with food · if you have pain"
    static func doseDetail(strength: String, foodNote: String, onlyIf: String) -> String {
        let only = onlyIf.isEmpty ? "" : "If \(PlainText.lowerFirst(onlyIf))"
        return [only, strength, foodNote].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

}

// MARK: - Ordering

extension SimpleDayItem {
    // now first, then any time, then later by time, finished at the bottom
    var rank: Int {
        switch state {
        case .now: return 0
        case .late: return 1
        case .anyTime: return kind == .asNeeded ? 3 : (kind == .goal ? 5 : 2)
        case .later: return 4
        case .done: return 6
        }
    }

    // by rank, then in the order they came
    static func sorted(_ items: [SimpleDayItem]) -> [SimpleDayItem] {
        items.enumerated().sorted { a, b in
            if a.element.rank != b.element.rank { return a.element.rank < b.element.rank }
            if a.element.sortDate != b.element.sortDate { return a.element.sortDate < b.element.sortDate }
            return a.offset < b.offset
        }.map(\.element)
    }

    // something home can put in the big card: not finished, not only-if-needed
    // a goal with no time is never the next thing
    var canLead: Bool { !isDone && kind != .asNeeded && kind != .rule && !(kind == .goal && state == .anyTime) }
}

// MARK: - The day as instructions

extension TodayViewModel {

    // MARK: Words

    static let simpleDoNowTitle = "Do this now"
    static let simpleDoFirstTitle = "Do this first"
    static let simpleAfterThatTitle = "After that"
    static let simpleAllDoneTitle = "All done for today"
    static let simpleAnyTimeText = "Any time today"
    static let simpleNothingOnDayText = "Nothing on your papers for this day."

    // "Day 3 of recovery", "Surgery in 9 days", "Surgery is today"
    var simpleTitle: String {
        switch layout {
        case .surgeryDay: return "Surgery is today"
        case .beforeSurgery, .afterSurgery: return headerTitle
        case .noPlan, .needsSurgeryDate: return "Today"
        }
    }

    // "Sunday, November 22"
    var simpleDetail: String { DayMath.longDate(now) }

    // MARK: Items

    // today's things as instructions in the order to do them, finished ones last
    func simpleDayItems(checkInDone: Bool = false) -> [SimpleDayItem] {
        guard layout != .noPlan, layout != .needsSurgeryDate else { return [] }
        var items: [SimpleDayItem] = []

        // something to stop today, before surgery
        let top = beforeTopCard
        if layout != .afterSurgery, top.kind == .stopToday {
            items.append(SimpleDayItem(id: "stop-today", kind: .stop, state: top.isDone ? .done : .now, sortDate: now,
                                       whenText: top.isDone ? "Done" : "Today",
                                       title: "Stop \(PlainText.list(top.names.map { Self.shortName($0) }))",
                                       detail: top.isDone ? top.doneText : top.detail,
                                       buttonTitle: top.isDone ? nil : "Put away"))
        }
        if layout == .surgeryDay {
            items.append(SimpleDayItem(id: "surgery-today", kind: .surgery, state: .now, sortDate: now,
                                       whenText: "Today", title: top.kind == .surgeryDay ? top.title : "Today is your surgery",
                                       detail: top.kind == .surgeryDay ? top.detail : ""))
        }

        // rules from the papers that apply today, like no eating
        for rule in rulesInEffectToday().prefix(4) {
            items.append(SimpleDayItem(id: rule.id, kind: .rule, state: .anyTime, sortDate: now,
                                       whenText: rule.startsToday ? "Starts today" : "Today",
                                       title: rule.title, detail: rule.detail))
        }

        // set-time doses
        for row in doseSections.flatMap(\.rows) {
            items.append(doseItem(row))
        }

        // only when needed
        for row in asNeededRows {
            let medicine = row.medicine
            items.append(SimpleDayItem(id: "prn-\(row.id.hashValue)", kind: .asNeeded, state: .anyTime,
                                       sortDate: now, whenText: row.canTake ? "If you need it" : row.status,
                                       title: SimpleInstruction.take(name: SimpleInstruction.everydayName(medicine), amount: medicine.amount),
                                       detail: SimpleInstruction.doseDetail(strength: medicine.strength, foodNote: medicine.foodNote, onlyIf: medicine.onlyIf),
                                       buttonTitle: row.canTake ? "Took one" : nil, asNeeded: row))
        }

        // visits today
        for visit in (plan?.appointments ?? []) where DayMath.calendar.isDate(visit.date, inSameDayAs: now) {
            let past = visit.date < now.addingTimeInterval(-30 * 60)
            items.append(SimpleDayItem(id: "visit-\(visit.persistentModelID.hashValue)", kind: .visit,
                                       state: past ? .done : (visit.date <= now.addingTimeInterval(30 * 60) ? .now : .later),
                                       sortDate: visit.date,
                                       whenText: past ? "Earlier \u{00B7} \(DayMath.timeText(of: visit.date))" : DayMath.timeText(of: visit.date),
                                       title: visit.title,
                                       detail: [visit.doctor, visit.place].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "),
                                       appointment: visit))
        }

        // evenings only, what tomorrow needs tonight, always after today's things
        for row in tonight {
            items.append(SimpleDayItem(id: "tonight-\(row.id)", kind: row.kind == .stop ? .stop : .visit, state: .later,
                                       sortDate: .distantFuture, whenText: "For tomorrow", title: row.title,
                                       detail: row.detail, appointment: row.visit))
        }

        // something to fill in
        if let action = hospitalAction {
            items.append(SimpleDayItem(id: "fill-hospital", kind: .fillIn, state: .anyTime, sortDate: now,
                                       whenText: "Before surgery", title: action.title, buttonTitle: "Add"))
        }

        // daily check-in, a to-do
        if showsCheckIn {
            let at = checkIn.timeToday(now: now)
            let passed = checkIn.checkInMinute.map { CheckInTime.hasPassed(minute: $0, now: now) } ?? false
            let timeText = checkIn.checkInMinute.map { CheckInTime.text(minute: $0) }
            let when = checkInDone ? "Done" : (timeText.map { passed ? "Any time \u{00B7} was \($0)" : $0 } ?? Self.simpleAnyTimeText)
            // a timed check-in sorts by its time, after it passes it is just anytime
            let state: SimpleDayItem.State = checkInDone ? .done : (at != nil && !passed ? .later : .anyTime)
            items.append(SimpleDayItem(id: "check-in", kind: .checkIn, state: state,
                                       sortDate: (checkInDone || passed) ? .distantFuture : (at ?? .distantFuture), whenText: when,
                                       title: "Check-in", detail: checkInDone ? "" : (passed ? "Check in when you can" : "How you feel today"),
                                       buttonTitle: checkInDone ? "Change" : "Start"))
        }

        // to-dos
        for (index, row) in taskRows.enumerated() {
            items.append(SimpleDayItem(id: "todo-\(row.id.hashValue)", kind: .todo, state: row.isDone ? .done : .anyTime,
                                       sortDate: Date.distantFuture.addingTimeInterval(TimeInterval(index + 1)),
                                       whenText: row.isDone ? "Done" : (row.detail.isEmpty ? Self.simpleAnyTimeText : SimpleWording.plain(row.detail)),
                                       title: row.title, buttonTitle: row.isDone ? nil : "Done", task: row))
        }

        // daily goals
        if layout == .afterSurgery {
            for tile in goalTiles {
                let title = tile.amountText.isEmpty ? tile.title : "\(tile.title), \(tile.amountText)"
                let minute = goalMinute(tile)
                let date = minute.flatMap { DayOrder.goalDate(minute: $0, on: now) }
                let when = DayOrder.goalWhen(minute: minute, now: now)
                let state: SimpleDayItem.State = tile.isComplete ? .done : (when == .now ? .now : (when == .later ? .later : .anyTime))
                let time = date.map { DayMath.timeText(of: $0) }
                let whenText = tile.isComplete ? "Done \u{00B7} \(tile.countText)"
                    : (time.map { "\($0) \u{00B7} \(tile.countText) done" } ?? "Any time \u{00B7} \(tile.countText) done")
                items.append(SimpleDayItem(id: "goal-\(tile.id.hashValue)", kind: .goal, state: state,
                                           sortDate: date ?? .distantFuture, whenText: whenText,
                                           title: title, buttonTitle: tile.isComplete ? nil : "Done", goal: tile))
            }
        }

        return SimpleDayItem.sorted(items)
    }

    // one dose as an instruction
    private func doseItem(_ row: DoseListRow) -> SimpleDayItem {
        let medicine = row.slot.medicine
        let state: SimpleDayItem.State
        let when: String
        switch row.state {
        case .due: state = .now; when = "Now \u{00B7} \(row.timeText)"
        case .missed: state = .late; when = "Missed \u{00B7} \(row.timeText)"
        case .upcoming: state = .later; when = row.timeText
        case .taken:
            state = .done
            when = "Done \u{00B7} \(DayMath.timeText(of: row.slot.log?.loggedAt ?? row.slot.scheduledFor))"
        case .skipped: state = .done; when = "Skipped \u{00B7} \(row.timeText)"
        }
        let open = state == .now || state == .late
        return SimpleDayItem(id: "dose-\(row.id.hashValue)", kind: .dose, state: state, sortDate: row.slot.scheduledFor,
                             whenText: when,
                             title: SimpleInstruction.take(name: SimpleInstruction.everydayName(medicine), amount: medicine.amount),
                             detail: SimpleInstruction.doseDetail(strength: medicine.strength, foodNote: medicine.foodNote, onlyIf: ""),
                             buttonTitle: open ? "Took it" : nil, doses: [row])
    }

    // a later day, read only: doses, visits, to-dos and stops in time order
    func simpleDayItems(daysAhead: Int) -> [SimpleDayItem] {
        guard daysAhead > 0 else { return simpleDayItems() }
        guard let plan, plan.surgeryDate != nil, layout != .noPlan, layout != .needsSurgeryDate else { return [] }
        let target = day + daysAhead
        let report = paperReport ?? PaperCheckReport.of(plan)
        var items: [SimpleDayItem] = []

        for medicine in plan.medicines where medicine.isConfirmed && medicine.action == .stop && medicine.startDay == target
            && !report.skipped.contains(medicine.persistentModelID, onDay: target) {
            items.append(SimpleDayItem(id: "stop-\(medicine.persistentModelID.hashValue)", kind: .stop, state: .anyTime,
                                       sortDate: .distantPast, whenText: "This day",
                                       title: "Stop \(SimpleInstruction.everydayName(medicine))", detail: medicine.reason))
        }
        for slot in DoseSchedule.slots(onDay: target, plan: plan, now: now, skipped: report.skipped) {
            let medicine = slot.medicine
            items.append(SimpleDayItem(id: "dose-\(slot.id.hashValue)", kind: .dose, state: .later, sortDate: slot.scheduledFor,
                                       whenText: DayMath.timeText(slot.minute),
                                       title: SimpleInstruction.take(name: SimpleInstruction.everydayName(medicine), amount: medicine.amount),
                                       detail: SimpleInstruction.doseDetail(strength: medicine.strength, foodNote: medicine.foodNote, onlyIf: "")))
        }
        let date = DayMath.calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now
        for visit in plan.appointments where DayMath.calendar.isDate(visit.date, inSameDayAs: date) {
            items.append(SimpleDayItem(id: "visit-\(visit.persistentModelID.hashValue)", kind: .visit, state: .later,
                                       sortDate: visit.date, whenText: DayMath.timeText(of: visit.date), title: visit.title,
                                       detail: [visit.doctor, visit.place].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "),
                                       appointment: visit))
        }
        for task in plan.tasks where !task.isDone && task.dueDay == target {
            items.append(SimpleDayItem(id: "todo-\(task.persistentModelID.hashValue)", kind: .todo, state: .anyTime,
                                       sortDate: .distantFuture, whenText: "Any time", title: task.title))
        }
        return SimpleDayItem.sorted(items)
    }

    // MARK: Home

    // the one thing for the big card, skipping what the patient put off for now
    static func simpleDoNow(_ items: [SimpleDayItem], snoozed: Set<String> = []) -> SimpleDayItem? {
        let open = items.filter(\.canLead)
        guard let first = open.first(where: { !snoozed.contains($0.id) }) ?? open.first else { return nil }
        // doses due at the same time go together, "I took it" logs them all
        guard first.kind == .dose, first.state == .now || first.state == .late else { return first }
        let together = open.filter { $0.kind == .dose && $0.state == first.state && $0.sortDate == first.sortDate }
        guard together.count > 1 else { return first }
        return SimpleDayItem(id: first.id, kind: .dose, state: first.state, sortDate: first.sortDate,
                             whenText: first.whenText, title: "Take \(together.count) medicines",
                             detail: PlainText.list(together.map { $0.title.replacingOccurrences(of: "Take ", with: "") }),
                             buttonTitle: first.buttonTitle, doses: together.flatMap(\.doses), members: together.map(\.id))
    }

    // the next two after the big card
    static func simpleAfterThat(_ items: [SimpleDayItem], leading: SimpleDayItem?, limit: Int = 2) -> [SimpleDayItem] {
        let used = Set([leading?.id].compactMap { $0 } + (leading?.members ?? []))
        // goals with no time show here only when something else leads
        let rows = items.filter { item in
            guard !used.contains(item.id), !item.isDone, item.kind != .asNeeded else { return false }
            return item.canLead || item.kind == .rule || (item.kind == .goal && leading != nil)
        }
        return Array(rows.prefix(limit))
    }

    // eyebrow on the big card
    static func simpleEyebrow(for item: SimpleDayItem) -> String {
        switch item.state {
        case .now, .anyTime: return simpleDoNowTitle
        case .late: return "Missed \u{00B7} \(item.whenText.components(separatedBy: " \u{00B7} ").last ?? "")"
        case .later: return "Next \u{00B7} \(item.whenText)"
        case .done: return simpleAllDoneTitle
        }
    }

    // what "All done" says next, like "Tomorrow at 8:00 AM: take Amlodipine"
    var simpleAllDoneDetail: String {
        simpleHeadlineText ?? "Nothing else is due today."
    }

    // "Read to me" on home
    func simpleSpokenHome(doNow: SimpleDayItem?, after: [SimpleDayItem], paperCheck: String?) -> String {
        var parts = [simpleTitle, simpleDetail]
        if let paperCheck { parts.append("\(Self.simpleDoFirstTitle). \(paperCheck)") }
        if let doNow {
            parts.append("\(Self.simpleEyebrow(for: doNow)). \(doNow.title). \(doNow.detail)")
        } else {
            parts.append("\(Self.simpleAllDoneTitle). \(simpleAllDoneDetail)")
        }
        if !after.isEmpty {
            parts.append("\(Self.simpleAfterThatTitle): " + after.map(\.spokenLabel).joined(separator: ". "))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    // MARK: Actions

    // logs every dose in the card as taken, one undo puts them all back
    func simpleTake(_ rows: [DoseListRow], in context: ModelContext) -> TodayUndo? {
        let open = rows.filter { $0.slot.log == nil }
        guard !open.isEmpty else { return nil }
        let undos = open.map { row in
            DoseActions.log(row.slot.medicine, scheduledFor: row.slot.scheduledFor, as: .taken, now: now, in: context)
        }
        return TodayUndo(message: "Marked as taken") { context in
            undos.forEach { DoseActions.undo($0, in: context) }
        }
    }

    // a goal's "Done", with an undo
    func simpleAddOne(to tile: GoalTile, in context: ModelContext) -> TodayUndo? {
        addOne(to: tile, in: context)
        let now = now
        return TodayUndo(message: "Well done") { context in
            GoalActions.removeOne(from: tile.goal, now: now, in: context)
        }
    }
}

// MARK: - Papers that disagree, as the first thing to do

extension PaperCheckCardData {
    var simpleHomeNoPhone: String { "No phone number on your papers. Call your care team." }
    // "Your papers disagree. Until you hear back, Remedy follows Dr. Rao's paper."
    var simpleHomeDetail: String {
        let detail = (followLine.isEmpty ? message.detail : followLine).trimmingCharacters(in: .whitespaces)
        return detail.isEmpty ? message.headline : "\(message.headline). \(detail)"
    }
}

// MARK: - The next thing in calendar words (for all done)

extension TodayViewModel {

    // everything coming up from now, for the headline rule
    var simpleAgenda: [SimpleAgendaItem] {
        guard let plan, plan.surgeryDate != nil, layout != .noPlan, layout != .needsSurgeryDate else { return [] }
        var items: [SimpleAgendaItem] = []
        let report = paperReport ?? PaperCheckReport.of(plan)

        for slot in todaySlots {
            let state: SimpleAgendaItem.State
            switch slot.state {
            case .due: state = .dueNow
            case .missed: state = .late
            case .upcoming: state = .upcoming
            case .taken, .skipped: continue
            }
            items.append(SimpleAgendaItem(kind: .dose, daysFromToday: 0, minute: slot.minute,
                                          title: MedicineText.everydayName(slot.medicine), state: state))
        }
        for ahead in 1...14 {
            for slot in DoseSchedule.slots(onDay: day + ahead, plan: plan, now: now, skipped: report.skipped) {
                items.append(SimpleAgendaItem(kind: .dose, daysFromToday: ahead, minute: slot.minute,
                                              title: MedicineText.everydayName(slot.medicine)))
            }
        }
        for visit in plan.appointments where visit.date >= now.addingTimeInterval(-30 * 60) {
            let ahead = DayMath.dayOffset(of: visit.date, from: now)
            items.append(SimpleAgendaItem(kind: .visit, daysFromToday: ahead, minute: DayMath.minuteOfDay(visit.date), title: visit.title))
        }
        for medicine in plan.medicines where medicine.isConfirmed && medicine.action == .stop {
            guard let start = medicine.startDay, start > day, !report.skipped.contains(medicine.persistentModelID, onDay: start) else { continue }
            items.append(SimpleAgendaItem(kind: .stop, daysFromToday: start - day, minute: nil,
                                          title: MedicineText.everydayName(medicine)))
        }
        return items
    }

    // "Tomorrow at 8:00 AM: take Amlodipine"
    var simpleHeadlineText: String? {
        SimpleHeadline.line(simpleAgenda, now: now)
    }
}

// MARK: - Short words other screens still use

extension TodayViewModel {

    // "tomorrow" stays as it is, a day name or date gets "on"
    static func onDay(_ word: String) -> String {
        ["today", "tomorrow", "yesterday"].contains(word) ? word : "on \(word)"
    }
}

// MARK: - Simple check-in, three short pages

extension CheckInViewModel {

    // the simple check-in's pages
    enum SimplePage: Int, CaseIterable { case pain, signs, note }

    var simplePageCount: Int { SimplePage.allCases.count }

    func simpleTitle(_ page: SimplePage) -> String {
        switch page {
        case .pain: return painTitle
        case .signs: return signs.isEmpty ? "Warning signs" : signsTitle
        case .note: return "Anything to add?"
        }
    }

    // "Page 1 of 3"
    func simplePageText(_ page: SimplePage) -> String { "Page \(page.rawValue + 1) of \(simplePageCount)" }

    var simpleNoPainText: String { "0 \u{00B7} No pain" }
    var simpleWorstText: String { "10 \u{00B7} Worst" }
    var simpleNextTitle: String { "Next" }
    var simpleBackTitle: String { "Back" }
    var simpleCloseTitle: String { "Close" }
    var simpleNoteHint: String { "Write a note for yourself or your doctor. You can leave it empty." }

    // what read to me says on each page
    func simpleSpoken(_ page: SimplePage, pain: Int, ticked: Set<String>) -> String {
        switch page {
        case .pain:
            return "\(painTitle) \(painScale) You picked \(pain)."
        case .signs:
            guard !signs.isEmpty else { return noSignsText }
            let picked = signs.filter { ticked.contains($0.text) }.map(\.text)
            return "\(signsTitle) " + signs.map(\.text).joined(separator: ". ")
                + (picked.isEmpty ? "" : ". You ticked: " + picked.joined(separator: ", "))
        case .note:
            return "\(simpleTitle(.note)) \(simpleNoteHint)"
        }
    }
}
