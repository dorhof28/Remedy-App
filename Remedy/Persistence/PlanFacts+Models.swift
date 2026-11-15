//
//  PlanFacts+Models.swift
//  Remedy
//
//  the saved models read by the pure rules in core
//

import Foundation
import SwiftData

extension DoseLog: DoseLogFacts {}

extension MedicineInstruction: MedicineFacts {
    var lineID: PersistentIdentifier { persistentModelID }
}

extension CareRule: RuleFacts {
    var lineID: PersistentIdentifier { persistentModelID }
}

extension CareTask: TaskFacts {
    var lineID: PersistentIdentifier { persistentModelID }
}

extension Appointment: VisitFacts {
    var lineID: PersistentIdentifier { persistentModelID }
}

extension CareContact: ContactFacts {}

extension CarePlan: PlanFacts {}
