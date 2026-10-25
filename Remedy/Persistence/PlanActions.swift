//
//  PlanActions.swift
//  Remedy
//
//  changes to the plan itself
//

import Foundation
import SwiftData

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
}
