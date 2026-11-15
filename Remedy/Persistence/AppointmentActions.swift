//
//  AppointmentActions.swift
//  Remedy
//
//  saves changes to visits
//

import Foundation
import SwiftData

// saves visit changes and keeps the calendar in step
enum AppointmentActions {

    // remembers the visit was added to Apple Calendar
    static func setInCalendar(_ appointment: Appointment, _ isInCalendar: Bool, eventID: String? = nil, in context: ModelContext) {
        appointment.isInCalendar = isInCalendar
        if let eventID { appointment.calendarEventID = eventID }
        if !isInCalendar { appointment.calendarEventID = nil }
        context.saveNow()
    }

    // what the form starts with
    static func draft(for appointment: Appointment) -> AppointmentDraft {
        AppointmentDraft(title: appointment.title, doctor: appointment.doctor, place: appointment.place,
                         phone: appointment.phone, notes: appointment.purpose, date: appointment.date)
    }

    // writes the form into the visit, or into a new one in the plan
    @discardableResult
    static func save(_ draft: AppointmentDraft, to appointment: Appointment?, in plan: CarePlan,
                     context: ModelContext) -> Appointment? {
        guard draft.canSave else { return nil }
        let target: Appointment
        if let appointment {
            target = appointment
        } else {
            let before = plan.surgeryDate.map { draft.date < $0 } ?? false
            target = Appointment(title: draft.trimmedTitle, date: draft.date,
                                 paper: before ? .beforeSurgery : .afterSurgery, quote: "")
            context.insert(target)
            target.plan = plan
        }
        target.title = draft.trimmedTitle
        target.date = draft.date
        target.doctor = draft.doctor.trimmingCharacters(in: .whitespacesAndNewlines)
        target.place = draft.place.trimmingCharacters(in: .whitespacesAndNewlines)
        target.phone = EditText.digits(draft.phone)
        target.purpose = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        context.saveNow()
        return target
    }

    // removes the visit, returns its calendar event so the caller can remove that too
    @discardableResult
    static func delete(_ appointment: Appointment, in context: ModelContext) -> String? {
        let eventID = appointment.calendarEventID
        context.delete(appointment)
        context.saveNow()
        return eventID
    }
}
