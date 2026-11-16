//
//  PlanActions.swift
//  Remedy
//
//  changes to the plan itself
//

import Foundation
import SwiftData

// changes to the plan itself: surgery date, hospital, times
enum PlanActions {

    
    // newest plan
    static func currentPlan(in context: ModelContext) -> CarePlan? {
        var descriptor = FetchDescriptor<CarePlan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // saves the surgery date
    static func setSurgeryDate(_ date: Date, on plan: CarePlan, in context: ModelContext) {
        plan.surgeryDate = DayMath.calendar.startOfDay(for: date)
        context.saveNow()
    }

    // saves the discharge date
    static func setDischargeDate(_ date: Date, on plan: CarePlan, in context: ModelContext) {
        plan.dischargeDate = DayMath.calendar.startOfDay(for: date)
        context.saveNow()
    }

    // deletes the plan and everything in it
    static func deletePlan(_ plan: CarePlan, in context: ModelContext) {
        context.delete(plan)
        context.saveNow()
    }

    // delete all data: every saved thing, check-ins, photos and office answers too, and the names to hide
    // ai keys and settings stay
    static func deleteEverything(in context: ModelContext) {
        for type in RemedySchema.models { deleteAll(type, in: context) }
        context.saveNow()
        PatientNames.save("")
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        for model in (try? context.fetch(FetchDescriptor<T>())) ?? [] { context.delete(model) }
    }
}
