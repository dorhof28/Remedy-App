//
//  Appointment.swift
//  Remedy
//
//  a visit
//

import Foundation
import SwiftData

// a visit from the papers or added by the patient, with what to bring and ask
@Model
final class Appointment {

    // info
    var title: String = ""
    var date: Date = Date()
    var doctor: String = ""
    var place: String = ""
    var address: String = ""
    var phone: String = ""
    var purpose: String = ""

    // for appt
    var bring: [String] = []

    // questions to ask at the visit
    var questions: [String] = []

    var isInCalendar: Bool = false
    // the calendar event made for this visit, so a change can move it
    var calendarEventID: String?

    // what paper info comes from
    var quote: String = ""
    var quotePage: Int?
    var paperRaw: String = PaperKind.afterSurgery.rawValue

    // plan it belongs to
    var paperID: UUID?      // the Paper record it came from
    var plan: CarePlan?

    init(title: String, date: Date, paper: PaperKind, quote: String) {
        self.title = title
        self.date = date
        self.paperRaw = paper.rawValue
        self.quote = quote
    }

    var paper: PaperKind {
        get { PaperKind(rawValue: paperRaw) ?? .afterSurgery }
        set { paperRaw = newValue.rawValue }
    }
}
