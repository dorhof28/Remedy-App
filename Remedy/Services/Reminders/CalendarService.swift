//
//  CalendarService.swift
//  Remedy
//
//  adds visits to calendar and to dos to reminders
//

import EventKit
import Foundation

enum CalendarService {

    // one store for the whole app
    static let store = EKEventStore()

    // MARK: - Calendar

    // visit event with alerts the day before and 2 hours before
    static func event(for appointment: Appointment) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = appointment.title
        event.startDate = appointment.date
        event.endDate = appointment.date.addingTimeInterval(60 * 60)
        event.location = [appointment.place, appointment.address].filter { !$0.isEmpty }.joined(separator: ", ")
        var notes: [String] = []
        if !appointment.purpose.isEmpty { notes.append(appointment.purpose) }
        if !appointment.bring.isEmpty { notes.append("Bring: " + PlainText.list(appointment.bring)) }
        if !appointment.phone.isEmpty { notes.append("Phone: " + DayMath.phoneText(appointment.phone)) }
        event.notes = notes.joined(separator: "\n\n")
        event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))
        event.addAlarm(EKAlarm(relativeOffset: -2 * 60 * 60))
        return event
    }

    // MARK: - Reminders app

    // adds every open to-do with a due day
    static func addToReminders(_ tasks: [CareTask], surgeryDate: Date) async throws -> Int {
        guard try await store.requestFullAccessToReminders() else { return 0 }
        let list = try remedyList()
        var added = 0
        for task in tasks where !task.isDone {
            let reminder = EKReminder(eventStore: store)
            reminder.title = task.title
            reminder.calendar = list
            if let due = task.dueDay {
                let date = DayMath.date(forDay: due, minute: ReminderPlan.taskMinute, from: surgeryDate)
                reminder.dueDateComponents = DayMath.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                reminder.addAlarm(EKAlarm(absoluteDate: date))
            }
            try store.save(reminder, commit: false)
            added += 1
        }
        try store.commit()
        return added
    }

    // the "Remedy" list in Reminders
    private static func remedyList() throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == "Remedy" }) {
            return existing
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = "Remedy"
        list.source = store.defaultCalendarForNewReminders()?.source ?? store.sources.first { $0.sourceType == .local }
        try store.saveCalendar(list, commit: true)
        return list
    }
}
