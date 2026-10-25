//
//  Appointment.swift
//  Remedy
//
//  a visit
//

import Foundation
import SwiftData

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

    // what paper info comes from
    var quote: String = ""
    var quotePage: Int?
    var paperRaw: String = PaperKind.afterSurgery.rawValue

    // plan it belongs to
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
