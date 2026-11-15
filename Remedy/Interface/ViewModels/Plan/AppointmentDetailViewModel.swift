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

// one visit: when, where, call, directions, what to bring and ask
struct AppointmentDetailViewModel {

    let appointment: Appointment
    let now: Date

    init(appointment: Appointment, now: Date) {
        self.appointment = appointment
        self.now = now
    }

    // MARK: - Words

    // "From: ..." which paper it came from, nil for old plans
    var sourceLine: String? { PaperSourceLine.text(paperID: appointment.paperID, in: appointment.plan) }

    let detailsTitle = "Details"
    let whyTitle = "Notes"
    let bringTitle = "Bring"
    let questionsTitle = "Questions to ask"
    let questionsFootnote = "Write the answers down, or ask if someone can come with you."
    let callTitle = "Call"
    let directionsTitle = "Directions"

    // MARK: - 1. Top card

    var title: String { appointment.title }

    // "Monday November 2 · 11:00 AM"
    var subtitle: String {
        "\(DayMath.longDate(appointment.date)) · \(DayMath.timeText(of: appointment.date))"
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
            rows.append(VisitDetailRow(id: "phone", symbol: "phone.fill", title: PhoneFormat.text(appointment.phone), subtitle: "Call if you\u{2019}re late or need to change it"))
        }
        return rows
    }

    // MARK: - 4. Why

    var purpose: String { appointment.purpose }
    var showsPurpose: Bool { !appointment.purpose.isEmpty }
    var quote: String { appointment.quote }
    var quoteSource: String { PlainText.source(paper: appointment.paper, page: appointment.quotePage) }

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
    func markAddedToCalendar(eventID: String? = nil, in context: ModelContext) {
        AppointmentActions.setInCalendar(appointment, true, eventID: eventID, in: context)
    }

    // MARK: - Redesigned visit page

    // "Tuesday, Nov 24 · 10:30 AM"
    var whenText: String {
        let date = appointment.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "\(date) \u{00B7} \(DayMath.timeText(of: appointment.date))"
    }

    // the place card: name first, address under it
    var placeTitle: String { appointment.place.isEmpty ? appointment.address : appointment.place }
    var placeDetail: String { appointment.place.isEmpty ? "" : appointment.address }
    var noPlaceText: String { "Your papers don\u{2019}t say where" }

    // the doctor row, call and text from the visit's number
    var doctorName: String { appointment.doctor.isEmpty ? "Office" : appointment.doctor }
    var doctorDetail: String { appointment.phone.isEmpty ? "No number on your papers" : PhoneFormat.text(appointment.phone) }
    var showsDoctor: Bool { !appointment.doctor.isEmpty || phoneURL != nil }
    var messageURL: URL? { appointment.phone.isEmpty ? nil : ContactLinks.messageURL(phone: appointment.phone) }

    // the paper it came from, for the source row
    var sourceTitle: String {
        appointment.paper == .beforeSurgery ? "From your before-surgery paper" : "From your after-surgery paper"
    }
    var sourceDetail: String {
        (sourceLine ?? "").replacingOccurrences(of: "From: ", with: "")
    }
    var showsSource: Bool { !quote.isEmpty || sourceLine != nil }

    // MARK: - Screen 40

    // "Mon, Nov 16 · 10:30 AM · about 1 hour"
    var headerSubtitle: String {
        [DayMath.shortDate(appointment.date), DayMath.timeText(of: appointment.date)].joined(separator: " \u{00B7} ")
    }

    // place, phone, doctor, bring and questions as plain rows
    var infoRows: [VisitDetailRow] {
        var rows: [VisitDetailRow] = []
        if !placeTitle.isEmpty {
            rows.append(VisitDetailRow(id: "place", symbol: "building.2", title: placeTitle, subtitle: placeDetail))
        }
        if !appointment.doctor.isEmpty {
            rows.append(VisitDetailRow(id: "doctor", symbol: "person", title: "Who you\u{2019}ll see", subtitle: appointment.doctor))
        }
        if !appointment.phone.isEmpty {
            rows.append(VisitDetailRow(id: "phone", symbol: "phone.fill", title: "Phone", subtitle: PhoneFormat.text(appointment.phone)))
        }
        if !purpose.isEmpty {
            rows.append(VisitDetailRow(id: "why", symbol: "info.circle", title: "Why", subtitle: purpose))
        }
        if !bringItems.isEmpty {
            rows.append(VisitDetailRow(id: "bring", symbol: "list.bullet", title: bringTitle,
                                       subtitle: PlainText.list(bringItems.enumerated().map { $0.offset == 0 ? $0.element : PlainText.lowerFirst($0.element) })))
        }
        return rows
    }

    var quoteText: String { quote.isEmpty ? "" : "\u{201C}\(quote)\u{201D}" }
    var quotePlain: String { PaperAbbreviations.explain(quote) }

    let editTitle = "Edit"
    let deleteTitle = "Delete visit"
    let deleteMessage = "This removes the visit from your plan, and from your calendar if you added it here."

    // removes the visit and its calendar event
    func delete(in context: ModelContext) {
        let eventID = AppointmentActions.delete(appointment, in: context)
        Task { await CalendarService.removeEvent(id: eventID) }
    }
}
