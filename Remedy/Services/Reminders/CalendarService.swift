//
//  CalendarService.swift
//  Remedy
//
//  adds visits to calendar and to dos to reminders
//

import EventKit
import Foundation
import SwiftData

// writes visits and plan days to the remedy calendar and to-dos to reminders
enum CalendarService {

    // one store for the whole app
    static let store = EKEventStore()

    // MARK: - Calendar

    // visit event with alerts the day before and 2 hours before
    static func event(for appointment: Appointment) -> EKEvent {
        let event = EKEvent(eventStore: store)
        fill(event, from: appointment)
        event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))
        event.addAlarm(EKAlarm(relativeOffset: -2 * 60 * 60))
        // the calendar they picked last time, else the phone's default
        event.calendar = chosenCalendar() ?? store.defaultCalendarForNewEvents
        return event
    }

    private static func fill(_ event: EKEvent, from appointment: Appointment) {
        event.title = appointment.title
        event.startDate = appointment.date
        event.endDate = appointment.date.addingTimeInterval(60 * 60)
        event.location = [appointment.place, appointment.address].filter { !$0.isEmpty }.joined(separator: ", ")
        var notes: [String] = []
        if !appointment.purpose.isEmpty { notes.append(appointment.purpose) }
        if !appointment.bring.isEmpty { notes.append("Bring: " + PlainText.list(appointment.bring)) }
        if !appointment.phone.isEmpty { notes.append("Phone: " + DayMath.phoneText(appointment.phone)) }
        event.notes = notes.joined(separator: "\n\n")
    }

    // MARK: - Calendar choice (which calendar a visit goes in, remembered)

    static let chosenCalendarKey = "calendarChoiceID"

    // one calendar in the picker, names only, no events are read
    struct CalendarChoice: Identifiable, Hashable {
        let id: String
        let title: String
        let account: String
    }

    // the saved pick, nil when never picked or the calendar is gone
    static func chosenCalendar(defaults: UserDefaults = .standard) -> EKCalendar? {
        guard let id = defaults.string(forKey: chosenCalendarKey),
              let calendar = store.calendar(withIdentifier: id), calendar.allowsContentModifications else { return nil }
        return calendar
    }

    // the calendar the patient picked last, so the add sheet starts there
    static func remember(_ calendar: EKCalendar?, defaults: UserDefaults = .standard) {
        defaults.set(calendar?.calendarIdentifier, forKey: chosenCalendarKey)
    }

    // calendars a visit can be added to, asks for access first, empty without it
    static func writableCalendars() async -> [CalendarChoice] {
        guard (try? await store.requestFullAccessToEvents()) == true else { return [] }
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title) }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
    }

    // the id to start the picker on
    static func startingCalendarID(in choices: [CalendarChoice], defaults: UserDefaults = .standard) -> String? {
        let saved = defaults.string(forKey: chosenCalendarKey)
        if let saved, choices.contains(where: { $0.id == saved }) { return saved }
        let fallback = store.defaultCalendarForNewEvents?.calendarIdentifier
        if let fallback, choices.contains(where: { $0.id == fallback }) { return fallback }
        return choices.first?.id
    }

    // puts the visit in that calendar, or moves and renames the event already made, returns its id
    static func addOrUpdate(_ appointment: Appointment, calendarID: String?) async -> String? {
        guard (try? await store.requestFullAccessToEvents()) == true else { return nil }
        let existing = appointment.calendarEventID.flatMap { store.event(withIdentifier: $0) }
        let event: EKEvent
        if let existing {
            event = existing
            fill(event, from: appointment)
        } else {
            event = Self.event(for: appointment)
        }
        if let calendarID, let calendar = store.calendar(withIdentifier: calendarID), calendar.allowsContentModifications {
            event.calendar = calendar
            remember(calendar)
        }
        if event.calendar == nil { event.calendar = store.defaultCalendarForNewEvents }
        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    // takes a deleted visit out of the calendar
    static func removeEvent(id: String?) async {
        guard let id, (try? await store.requestFullAccessToEvents()) == true,
              let event = store.event(withIdentifier: id) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
    }

    // MARK: - Remedy calendar (kept in step with the plan)

    static let planOnKey = "calendarPlanOn"
    private static let stateKey = "calendarPlanState"

    // the saved ids: only these are ever looked up, other calendars are never read
    private struct State: Codable {
        var calendarID: String?
        var events: [String: String] = [:]      // plan key to event id
    }

    // one event the plan wants
    struct Want {
        let title: String
        let start: Date
        let end: Date
        let allDay: Bool
        let notes: String
    }

    // what remedy last wrote, so a sync only changes what moved
    private static func loadState(_ defaults: UserDefaults) -> State {
        defaults.data(forKey: stateKey).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    private static func saveState(_ state: State, _ defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(state), forKey: stateKey)
    }

    // events the plan wants: surgery, stop days, visits, to-dos
    private static func wants(for plan: CarePlan) -> [String: Want] {
        guard let surgeryDate = plan.surgeryDate else { return [:] }
        var result: [String: Want] = [:]
        // an all day event on a plan day
        func allDay(_ title: String, day: Int, notes: String = "") -> Want {
            let date = DayMath.date(forDay: day, from: surgeryDate)
            return Want(title: title, start: date, end: date, allDay: true, notes: notes)
        }
        result["surgery"] = allDay(plan.procedure.isEmpty ? "Surgery" : plan.procedure, day: 0)
        let skipped = PaperCheckReport.of(plan).skipped
        for med in plan.medicines where med.isConfirmed && med.action == .stop {
            guard let day = med.startDay, !skipped.contains(med.persistentModelID, onDay: day) else { continue }
            let key = "stop-\(day)"
            let name = MedicineText.everydayName(med)
            let title = result[key].map { $0.title + ", " + name } ?? "Stop: " + name
            result[key] = allDay(title, day: day)
        }
        for visit in plan.appointments {
            var key = "visit-\(visit.title)"
            while result[key] != nil { key += "+" }
            result[key] = Want(title: visit.title, start: visit.date, end: visit.date.addingTimeInterval(3600),
                               allDay: false, notes: notes(for: visit))
        }
        for task in plan.tasks where !task.isDone {
            guard let day = task.dueDay else { continue }
            var key = "task-\(task.title)"
            while result[key] != nil { key += "+" }
            result[key] = allDay("To do: " + task.title, day: day)
        }
        return result
    }

    // the visit's purpose, what to bring and questions as event notes
    private static func notes(for visit: Appointment) -> String {
        var notes: [String] = []
        if !visit.purpose.isEmpty { notes.append(visit.purpose) }
        if !visit.bring.isEmpty { notes.append("Bring: " + PlainText.list(visit.bring)) }
        return notes.joined(separator: "\n\n")
    }

    // adds, moves or removes events so the calendar matches the plan, returns false without permission
    @discardableResult
    static func syncPlan(_ plan: CarePlan?, defaults: UserDefaults = .standard) async -> Bool {
        await sync(snapshot(of: plan), defaults: defaults)
    }

    // the events a plan wants, read now so a later sync never touches a deleted plan
    static func snapshot(of plan: CarePlan?) -> [String: Want] {
        guard let plan, !plan.isDeleted, plan.modelContext != nil else { return [:] }
        return wants(for: plan)
    }

    // adds, moves or removes events to match a snapshot, returns false without permission
    @discardableResult
    static func sync(_ wanted: [String: Want], defaults: UserDefaults = .standard) async -> Bool {
        guard (try? await store.requestFullAccessToEvents()) == true else { return false }
        var state = loadState(defaults)
        do {
            let calendar = try remedyCalendar(&state)
            for (key, want) in wanted {
                let existing = state.events[key].flatMap { store.event(withIdentifier: $0) }
                let event = existing ?? EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = want.title
                event.isAllDay = want.allDay
                event.startDate = want.start
                event.endDate = want.end
                event.notes = want.notes
                if existing == nil, !want.allDay {
                    event.addAlarm(EKAlarm(relativeOffset: -2 * 60 * 60))
                }
                try store.save(event, span: .thisEvent, commit: true)
                state.events[key] = event.eventIdentifier
            }
            for (key, id) in state.events where wanted[key] == nil {
                if let event = store.event(withIdentifier: id) {
                    try store.remove(event, span: .thisEvent, commit: false)
                }
                state.events[key] = nil
            }
            try store.commit()
            saveState(state, defaults)
            return true
        } catch {
            return false
        }
    }

    // are there events from an earlier plan still saved
    static func hasSavedEvents(defaults: UserDefaults = .standard) -> Bool {
        let state = loadState(defaults)
        return state.calendarID != nil || !state.events.isEmpty
    }

    // turning the switch off removes every event and the Remedy calendar
    static func removePlan(defaults: UserDefaults = .standard) async {
        guard (try? await store.requestFullAccessToEvents()) == true else { return }
        let state = loadState(defaults)
        for id in state.events.values {
            if let event = store.event(withIdentifier: id) { try? store.remove(event, span: .thisEvent, commit: false) }
        }
        try? store.commit()
        if let id = state.calendarID, let calendar = store.calendar(withIdentifier: id) {
            try? store.removeCalendar(calendar, commit: true)
        }
        defaults.removeObject(forKey: stateKey)
    }

    // our own calendar found by its saved id, or made new
    private static func remedyCalendar(_ state: inout State) throws -> EKCalendar {
        if let id = state.calendarID, let existing = store.calendar(withIdentifier: id) { return existing }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Remedy"
        calendar.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first { $0.sourceType == .local }
        try store.saveCalendar(calendar, commit: true)
        state.calendarID = calendar.calendarIdentifier
        state.events = [:]
        return calendar
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
