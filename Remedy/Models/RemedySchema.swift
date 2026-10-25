//
//  RemedySchema.swift
//  Remedy
//
//  swiftdata schema and in memory option for tests
//

import SwiftData

enum RemedySchema {
    static let models: [any PersistentModel.Type] = [
        CarePlan.self,
        MedicineInstruction.self,
        DoseLog.self,
        CareRule.self,
        CareTask.self,
        Appointment.self,
        DailyGoal.self,
        GoalLog.self,
        CareContact.self,
        SourceDocument.self,
        ChatMessage.self,
    ]
}
