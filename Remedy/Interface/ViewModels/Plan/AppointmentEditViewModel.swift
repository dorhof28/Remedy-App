//
//  AppointmentEditViewModel.swift
//  Remedy
//
//  add or change one visit, for both looks
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// the visit edit form, also keeps the calendar event in step
@MainActor
@Observable
final class AppointmentEditViewModel {

    enum Field: Hashable, CaseIterable {
        case title, doctor, place, phone, notes
    }

    var draft: AppointmentDraft
    var showsProblems = false

    // calendar
    var addsToCalendar: Bool
    var calendars: [CalendarService.CalendarChoice] = []
    var calendarID: String?
    var calendarDenied = false
    var isSaving = false

    let appointment: Appointment?
    let plan: CarePlan
    private let original: AppointmentDraft
    private let wasInCalendar: Bool

    init(appointment: Appointment?, plan: CarePlan, now: Date) {
        self.appointment = appointment
        self.plan = plan
        let start = appointment.map { AppointmentActions.draft(for: $0) }
            ?? AppointmentDraft(date: Self.defaultDate(plan: plan, now: now))
        self.draft = start
        self.original = start
        // a visit added with Apple's own screen has no event we can move
        let linked = appointment.map { $0.isInCalendar && $0.calendarEventID != nil } ?? false
        self.wasInCalendar = linked
        self.addsToCalendar = linked
    }

    // tomorrow at 9 AM
    static func defaultDate(plan: CarePlan, now: Date) -> Date {
        let tomorrow = DayMath.calendar.date(byAdding: .day, value: 1, to: DayMath.calendar.startOfDay(for: now)) ?? now
        return tomorrow.addingTimeInterval(9 * 3600)
    }

    // MARK: - Words

    var isNew: Bool { appointment == nil }
    var title: String { isNew ? "Add visit" : "Edit visit" }
    var saveTitle: String { "Save" }
    let deleteTitle = "Delete visit"
    let deleteMessage = "This removes the visit from your plan, and from your calendar if you added it here."
    let titleLabel = "What is it"
    let titlePrompt = "Like Check-up"
    let doctorLabel = "Doctor"
    let doctorPrompt = "Like Dr. Smith"
    let placeLabel = "Place"
    let placePrompt = "Clinic or hospital"
    let phoneLabel = "Phone"
    let phonePrompt = "Phone number"
    let notesLabel = "Notes"
    let notesPrompt = "Anything to remember"
    let dayLabel = "Day"
    let timeLabel = "Time"
    let calendarLabel = "Calendar"
    let calendarTitle = "Add to my calendar"
    let discardTitle = "Discard changes?"
    let calendarDeniedText = "Calendar access is off. You can turn it on in Settings."

    var hasChanges: Bool { draft != original || addsToCalendar != wasInCalendar }
    var problems: [String] { showsProblems ? draft.problems : [] }
    // the sentence under the what is it field
    var titleProblem: String? { problems.first }

    // only said when it matters
    var calendarNote: String {
        guard let appointment, appointment.isInCalendar, appointment.calendarEventID == nil else { return "" }
        return "Already in your calendar from before. Changes here won\u{2019}t move that event."
    }

    // MARK: - Focus

    var focusOrder: [Field] { Field.allCases }
    func nextField(after field: Field) -> Field? { FocusOrder.next(after: field, in: focusOrder) }
    func submitLabel(for field: Field) -> SubmitLabel { FocusOrder.isLast(field, in: focusOrder) ? .done : .next }
    func keyboardButtonTitle(for field: Field) -> String { FocusOrder.isLast(field, in: focusOrder) ? "Done" : "Next" }

    // MARK: - Calendar

    // loads the calendars the first time the switch goes on
    func loadCalendars() async {
        guard calendars.isEmpty else { return }
        calendars = await CalendarService.writableCalendars()
        calendarDenied = calendars.isEmpty
        if calendarID == nil { calendarID = CalendarService.startingCalendarID(in: calendars) }
        if calendarDenied { addsToCalendar = false }
    }

    // MARK: - Actions

    // true when saved
    func save(in context: ModelContext) async -> Bool {
        guard draft.canSave else {
            showsProblems = true
            return false
        }
        isSaving = true
        defer { isSaving = false }
        guard let saved = AppointmentActions.save(draft, to: appointment, in: plan, context: context) else { return false }
        if addsToCalendar {
            if let id = await CalendarService.addOrUpdate(saved, calendarID: calendarID) {
                AppointmentActions.setInCalendar(saved, true, eventID: id, in: context)
            }
        } else if wasInCalendar {
            await CalendarService.removeEvent(id: saved.calendarEventID)
            AppointmentActions.setInCalendar(saved, false, in: context)
        }
        PlanSync.refresh(plan)
        return true
    }

    // deletes the visit and its calendar event
    func delete(in context: ModelContext) {
        guard let appointment else { return }
        let eventID = AppointmentActions.delete(appointment, in: context)
        Task { await CalendarService.removeEvent(id: eventID) }
        PlanSync.refresh(plan)
    }
}
