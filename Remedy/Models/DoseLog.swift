//
//  DoseLog.swift
//  Remedy
//
//  one taken or skipped dose
//

import Foundation
import SwiftData

@Model
final class DoseLog {

    var scheduledFor: Date = Date()
    var loggedAt: Date = Date()
    var statusRaw: String = DoseStatus.taken.rawValue

    
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
