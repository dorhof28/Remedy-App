//
//  CarePlan.swift
//  Remedy
//
//  root of all info
//

import Foundation
import SwiftData

@Model
final class CarePlan {

    
    var procedure: String = ""
    var surgeryDate: Date?
    var dischargeDate: Date?

    // where the plan came from
    var sourceRaw: String = PlanSource.scan.rawValue

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MedicineInstruction.plan)
    var medicines: [MedicineInstruction] = []

    @Relationship(deleteRule: .cascade, inverse: \CareRule.plan)
    var rules: [CareRule] = []

    @Relationship(deleteRule: .cascade, inverse: \CareTask.plan)
    var tasks: [CareTask] = []

    @Relationship(deleteRule: .cascade, inverse: \Appointment.plan)
    var appointments: [Appointment] = []

    @Relationship(deleteRule: .cascade, inverse: \DailyGoal.plan)
    var goals: [DailyGoal] = []

    @Relationship(deleteRule: .cascade, inverse: \CareContact.plan)
    var contacts: [CareContact] = []

    @Relationship(deleteRule: .cascade, inverse: \SourceDocument.plan)
    var documents: [SourceDocument] = []

    init(procedure: String, surgeryDate: Date? = nil, source: PlanSource = .scan) {
        self.procedure = procedure
        self.surgeryDate = surgeryDate
        self.sourceRaw = source.rawValue
    }

    var source: PlanSource {
        get { PlanSource(rawValue: sourceRaw) ?? .scan }
        set { sourceRaw = newValue.rawValue }
    }
}
