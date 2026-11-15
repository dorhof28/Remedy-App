//
//  DoseLog.swift
//  Remedy
//
//  one taken or skipped dose
//

import Foundation
import SwiftData

// one answer for one dose: taken or skipped, and when
@Model
final class DoseLog {

    var scheduledFor: Date = Date()
    var loggedAt: Date = Date()
    var statusRaw: String = DoseStatus.taken.rawValue
    // the patient changed the answer or the time in the dose log
    var changedByYou: Bool = false

    var medicine: MedicineInstruction?

    init(scheduledFor: Date, status: DoseStatus, loggedAt: Date = Date()) {
        self.scheduledFor = scheduledFor
        self.statusRaw = status.rawValue
        self.loggedAt = loggedAt
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }
}
