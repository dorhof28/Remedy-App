//
//  AppointmentActions.swift
//  Remedy
//
//  saves changes to visits
//

import Foundation
import SwiftData

enum AppointmentActions {

    // remembers the visit was added to Apple Calendar
    static func setInCalendar(_ appointment: Appointment, _ isInCalendar: Bool, in context: ModelContext) {
        appointment.isInCalendar = isInCalendar
        context.saveNow()
    }
}
