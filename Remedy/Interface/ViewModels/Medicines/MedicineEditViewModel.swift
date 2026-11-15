//
//  MedicineEditViewModel.swift
//  Remedy
//
//  add or change one medicine, for both looks
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// the medicine edit form: fields, checks and save
@MainActor
@Observable
final class MedicineEditViewModel {

    // the fields in the order the return key walks through them
    enum Field: Hashable {
        case name, amount, purpose, notes
    }

    var draft: MedicineDraft
    // true after a failed save so the reasons show
    var showsProblems = false

    let medicine: MedicineInstruction?
    let plan: CarePlan
    let now: Date
    private let original: MedicineDraft

    // the line just saved, the restart finishes with it
    var savedLine: MedicineInstruction?

    // a restart starts from the stopped line's name and amount, as a new line
    var preset: MedicineDraft?

    init(medicine: MedicineInstruction?, plan: CarePlan, now: Date, preset: MedicineDraft? = nil) {
        self.medicine = medicine
        self.plan = plan
        self.now = now
        self.preset = preset
        let start = preset ?? medicine.map { MedicineActions.draft(for: $0) } ?? MedicineDraft(times: [8 * 60])
        self.draft = start
        self.original = start
    }

    // MARK: - Words

    var isNew: Bool { medicine == nil }
    var title: String { isNew ? (preset == nil ? "Add Medicine" : "Restart Medicine") : "Edit Medicine" }
    // "Delete Aspirin 81 mg"
    var deleteRowTitle: String { "Delete \(medicine.map { MedicineText.fullName($0) } ?? "Medicine")" }
    let groupLabel = "Group"
    let startLabel = "Start"
    let stopLabel = "Stop"
    let groupsFooter = "Groups: Every day, Only when needed, Stopped for now, Finished. Times follow your iPhone\u{2019}s 12- or 24-hour setting."
    let notesRowPrompt = "Notes, like \u{201C}with food\u{201D}"

    // "8:00 AM · 8:00 PM"
    var timesText: String {
        MedicineDraft.cleanTimes(draft.times).map { DayMath.timeText($0) }.joined(separator: " \u{00B7} ")
    }

    // "Mon, Nov 9", "None"
    func dayText(_ day: Int?) -> String {
        guard let day, let surgery = plan.surgeryDate else { return "None" }
        return DayMath.shortDate(forDay: day, from: surgery)
    }

    // finished is not picked, a stop date in the past makes it finished
    var groupOptions: [MedicineAction] {
        draft.action == .okToTake || medicine?.action == .okToTake ? [.take, .takeAsNeeded, .stop, .okToTake] : [.take, .takeAsNeeded, .stop]
    }

    func groupTitle(for action: MedicineAction) -> String {
        switch action {
        case .take: return "Every day"
        case .takeAsNeeded: return "Only when needed"
        case .stop: return "Stopped for now"
        case .okToTake: return "Keep taking as usual"
        }
    }
    var saveTitle: String { "Save" }
    let deleteTitle = "Delete medicine"
    var deleteMessage: String { "This removes it from your plan and its dose history on this phone." }
    let nameLabel = "Name"
    let namePrompt = "Like Tylenol"
    let amountLabel = "Amount"
    let amountPrompt = "Like 1 tablet"
    let notesLabel = "Notes"
    let notesPrompt = "With food, for example"
    let maxPrompt = "Most a day"
    let minHoursPrompt = "Hours between"
    let notSetText = "Not set"
    let addTimeTitle = "Add a time"
    let timesLabel = "Times"
    let actionTitle = "What to do"
    let discardTitle = "Discard changes?"
    let timesTitle = "Times each day"
    let datesTitle = "Dates"
    let limitsFooter = "Remedy waits this long after the last dose before it says you can take another."
    // 96 and 97 words
    let limitsHeader = "Limits"
    let purposeLabel = "For"
    let purposePrompt = "Like severe pain"
    let hoursLimitTitle = "Hours between doses"
    let mostLimitTitle = "Most in a day"
    let timesPageTitle = "Times"
    let addATime = "Add a Time"
    let timesFooter = "Times follow your iPhone\u{2019}s 12- or 24-hour setting. An every-day medicine needs at least one time."
    let noTimesFooter = "Add at least one time."
    func removeTimeLabel(_ index: Int) -> String { "Remove \(DayMath.timeText(of: time(at: index)))" }
    let closeTitle = "Close"
    let cancelTitle = "Cancel"

    // the four choices of the capsule picker
    var actionOptions: [MedicineAction] { [.take, .takeAsNeeded, .stop, .okToTake] }

    func title(for action: MedicineAction) -> String {
        switch action {
        case .take: return "Take"
        case .stop: return "Stop"
        case .takeAsNeeded: return "As needed"
        case .okToTake: return "Allowed"
        }
    }

    // MARK: - Steppers

    // most a day as a number, nil shows Not set, the first tap starts at the usual 4
    var maxPerDayValue: Int? {
        get { EditText.number(draft.maxPerDay) }
        set { draft.maxPerDay = newValue.map { "\(min(max($0, 1), 24))" } ?? "" }
    }

    var minHoursValue: Int? {
        get { EditText.number(draft.minHours) }
        set { draft.minHours = newValue.map { "\(min(max($0, 1), 48))" } ?? "" }
    }

    func stepMax(_ up: Bool) { maxPerDayValue = Self.step(maxPerDayValue, up: up, start: 4, range: 1...24) }
    func stepHours(_ up: Bool) { minHoursValue = Self.step(minHoursValue, up: up, start: 6, range: 1...48) }

    // one step up or down, below the lowest goes back to Not set
    static func step(_ value: Int?, up: Bool, start: Int, range: ClosedRange<Int>) -> Int? {
        guard let value else { return up ? start : nil }
        let next = value + (up ? 1 : -1)
        if next < range.lowerBound { return nil }
        return min(next, range.upperBound)
    }

    // MARK: - Problems next to their field

    // a field that has a problem
    enum ProblemField { case name, times, dates, maxPerDay, minHours }

    // the plain sentence under one field, nil when it is fine or not saved yet
    func problem(for field: ProblemField) -> String? {
        let words: String
        switch field {
        case .name: words = "medicine name"
        case .times: words = "time each day"
        case .dates: words = "last day"
        case .maxPerDay: words = "Most a day"
        case .minHours: words = "Hours between"
        }
        return problems.first { $0.contains(words) }
    }

    var startTitle: String { draft.action == .stop ? "Stop from" : "Start day" }
    var endTitle: String { draft.action == .stop ? "Until" : "Stop day" }

    // dates are counted from surgery, so they need that date
    var canEditDates: Bool { plan.surgeryDate != nil }
    var hasChanges: Bool { draft != original }
    var problems: [String] { showsProblems ? draft.problems : [] }

    // MARK: - Focus

    var focusOrder: [Field] {
        // most a day and hours between are steppers, no typing
        [.name, .amount, .purpose, .notes]
    }

    func nextField(after field: Field) -> Field? { FocusOrder.next(after: field, in: focusOrder) }

    func submitLabel(for field: Field) -> SubmitLabel {
        FocusOrder.isLast(field, in: focusOrder) ? .done : .next
    }

    // the key on top of the number pad
    func keyboardButtonTitle(for field: Field) -> String {
        FocusOrder.isLast(field, in: focusOrder) ? "Done" : "Next"
    }

    // MARK: - Times

    // a dose time as a date on today so the time picker can show it
    func time(at index: Int) -> Date {
        let minute = draft.times.indices.contains(index) ? draft.times[index] : 8 * 60
        return DayMath.date(forDay: 0, minute: minute, from: now)
    }

    func setTime(_ date: Date, at index: Int) {
        guard draft.times.indices.contains(index) else { return }
        draft.times[index] = DayMath.minuteOfDay(date)
    }

    func addTime() { draft.times.append(MedicineDraft.nextTime(after: draft.times)) }

    func removeTime(at index: Int) {
        guard draft.times.indices.contains(index) else { return }
        draft.times.remove(at: index)
    }

    // MARK: - Dates

    // today as a plan day, where a new date starts
    private var todayDay: Int { DoseSchedule.today(for: plan, now: now) ?? 0 }

    private func date(forDay day: Int?) -> Date {
        guard let surgery = plan.surgeryDate else { return now }
        return DayMath.date(forDay: day ?? todayDay, from: surgery)
    }

    private func day(for date: Date) -> Int {
        plan.surgeryDate.map { DayMath.dayOffset(of: date, from: $0) } ?? 0
    }

    var hasStart: Bool {
        get { draft.startDay != nil }
        set { draft.startDay = newValue ? (draft.startDay ?? todayDay) : nil }
    }

    var hasEnd: Bool {
        get { draft.endDay != nil }
        set { draft.endDay = newValue ? (draft.endDay ?? max(todayDay, draft.startDay ?? todayDay) + 7) : nil }
    }

    var startDate: Date {
        get { date(forDay: draft.startDay) }
        set { draft.startDay = day(for: newValue) }
    }

    var endDate: Date {
        get { date(forDay: draft.endDay) }
        set { draft.endDay = day(for: newValue) }
    }

    // MARK: - Actions

    // true when saved, false shows what is missing
    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard draft.canSave else {
            showsProblems = true
            return false
        }
        savedLine = MedicineActions.save(draft, to: medicine, in: plan, now: now, context: context)
        PlanSync.refresh(plan)
        return true
    }

    // the caller closes its screen first, then this removes it
    func delete(in context: ModelContext) {
        guard let medicine else { return }
        MedicineActions.delete(medicine, in: context)
        PlanSync.refresh(plan)
    }
}
