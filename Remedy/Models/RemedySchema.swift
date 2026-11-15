//
//  RemedySchema.swift
//  Remedy
//
//  swiftdata schema and in memory option for tests
//

import SwiftData

enum RemedySchema {
    // saved plans must keep opening after an update
    // new stored properties must be optional or have a default
    // renames use @Attribute(originalName:) never a plain rename
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
        Paper.self,
        PaperCheckNote.self,
        PhotoTrack.self,
        PhotoEntry.self,
        CheckIn.self,
    ]
}
