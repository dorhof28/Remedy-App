//
//  AppointmentDetailViewModel.swift
//  Remedy
//
//  one visit for both looks
//

import EventKit
import Foundation
import SwiftData

// MARK: - Date tile pieces (shared with the Plan tab's visit list)

// "NOV" / "2" / "Mon" for a DateTile
struct DateParts {
    let month: String
    let day: String
    let weekday: String

    init(_ date: Date) {
        month = Self.monthFormatter.string(from: date).uppercased()
        day = DayMath.dayNumber(forDay: 0, from: date)
        weekday = DayMath.weekdayLetters(forDay: 0, from: date)
    }

    // "today" "tomorrow" "in 4 days" "2 days ago"
    static func relative(_ date: Date, now: Date) -> String {
        DayMath.relative(daysFromToday: DayMath.dayOffset(of: date, from: now))
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()
}

// one line in the Details card [icon] Dr
struct VisitDetailRow: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let subtitle: String
}

// MARK: - ViewModel

struct AppointmentDetailViewModel {

    let appointment: Appointment
    let now: Date

    init(appointment: Appointment, now: Date) {
        self.appointment = appointment
        self.now = now
    }

    // MARK: - Words

    let detailsTitle = "Details"
    let whyTitle = "Why you\u{2019}re going"
    let bringTitle = "Bring"
    let questionsTitle = "Questions to ask"
    let questionsFootnote = "Write the answers down, or ask if someone can come with you."
    let callTitle = "Call"
    let directionsTitle = "Directions"

    // MARK: - 1. Top card

    var title: String { appointment.title }
    var dateParts: DateParts { DateParts(appointment.date) }

    // "Monday November 2 · 11:00 AM"
    var subtitle: String {
        "\(DayMath.longDate(appointment.date)) · \(DayMath.timeText(of: appointment.date))"
    }

    // "In 4 days" / "Today" / "Was 2 days ago"
    var relativeText: String {
        let words = DateParts.relative(appointment.date, now: now)
        if isPast { return "Was \(words)" }
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    private var isPast: Bool {
        DayMath.dayOffset(of: appointment.date, from: now) < 0
    }

    // MARK: - 2. Buttons

    var isInCalendar: Bool { appointment.isInCalendar }
    var calendarButtonTitle: String { isInCalendar ? "In your calendar" : "Add to Calendar" }
    var calendarButtonSymbol: String { isInCalendar ? "calendar.badge.checkmark" : "calendar.badge.plus" }
    var showsCalendarButton: Bool { !isPast }

    var phoneURL: URL? { appointment.phone.isEmpty ? nil : DayMath.phoneURL(appointment.phone) }
    var mapsURL: URL? { appointment.address.isEmpty ? nil : DayMath.mapsURL(appointment.address) }
    var showsContactButtons: Bool { phoneURL != nil || mapsURL != nil }

    // MARK: - 3. Details

    var detailRows: [VisitDetailRow] {
        var rows: [VisitDetailRow] = []
        if !appointment.doctor.isEmpty {
            rows.append(VisitDetailRow(id: "doctor", symbol: "person.fill", title: appointment.doctor, subtitle: "Who you\u{2019}ll see"))
        }
        if !appointment.place.isEmpty || !appointment.address.isEmpty {
            let title = appointment.place.isEmpty ? appointment.address : appointment.place
            let subtitle = appointment.place.isEmpty ? "" : appointment.address
            rows.append(VisitDetailRow(id: "place", symbol: "building.2.fill", title: title, subtitle: subtitle))
        }
        if !appointment.phone.isEmpty {
            rows.append(VisitDetailRow(id: "phone", symbol: "phone.fill", title: DayMath.phoneText(appointment.phone), subtitle: "Call if you\u{2019}re late or need to change it"))
        }
        return rows
    }
    var showsDetails: Bool { !detailRows.isEmpty }

    // MARK: - 4. Why

    var purpose: String { appointment.purpose }
    var showsPurpose: Bool { !appointment.purpose.isEmpty }
    var quote: String { appointment.quote }
    var quoteSource: String { PlainText.source(paper: appointment.paper, page: appointment.quotePage) }
    var showsWhy: Bool { showsPurpose || !quote.isEmpty }

    // MARK: - 5. Bring

    var bringItems: [String] { appointment.bring }
    var showsBring: Bool { !bringItems.isEmpty }

    // MARK: - 6. Questions

    var questions: [String] { appointment.questions }
    var showsQuestions: Bool { !questions.isEmpty }

    // MARK: - Actions

    // already added = the button is greyed out
    var canAddToCalendar: Bool { !isInCalendar }

    // the filled-in event for Apple's "New Event" screen
    func calendarEvent() -> EKEvent {
        CalendarService.event(for: appointment)
    }

    // the patient tapped Add on Apple's screen
    func markAddedToCalendar(in context: ModelContext) {
        AppointmentActions.setInCalendar(appointment, true, in: context)
    }
}
