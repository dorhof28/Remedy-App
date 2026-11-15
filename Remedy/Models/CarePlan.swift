//
//  CarePlan.swift
//  Remedy
//
//  root of all info
//

import Foundation
import SwiftData

// one surgery and everything from its papers, deleting it deletes all of it
@Model
final class CarePlan {

    
    var procedure: String = ""
    var surgeryDate: Date?
    var dischargeDate: Date?

    // hospital arrival and place for surgery day
    var arrivalTime: Date?
    var hospitalName: String?
    var hospitalAddress: String?
    // which door and desk on the day, and when surgery starts
    var hospitalWhereToGo: String?
    var surgeryStartTime: Date?

    // where the plan came from
    var sourceRaw: String = PlanSource.scan.rawValue

    var createdAt: Date = Date()

    // daily check-in time in minutes after midnight, nil until the patient picks one
    var checkInMinute: Int?
    // how often the time prompt was dismissed and on which plan day last
    var checkInPromptDismissals: Int = 0
    var checkInPromptLastDay: Int?

    // true for the sample plan and plans from pre-made sample papers
    var isSample: Bool = false

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

    @Relationship(deleteRule: .cascade, inverse: \Paper.plan)
    var papers: [Paper] = []

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
