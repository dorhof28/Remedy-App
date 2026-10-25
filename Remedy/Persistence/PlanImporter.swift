//
//  PlanImporter.swift
//  Remedy
//
//  saves the confirmed draft to swiftdata
//

import Foundation
import SwiftData

enum PlanImporter {

    // saves the draft and returns the plan it went into
    @discardableResult
    static func save(_ draft: DraftPlan, in context: ModelContext) -> CarePlan {
        let plan = planToFill(for: draft, in: context)
        let paper = draft.paper

        for item in draft.medicines where item.isConfirmed {
            let medicine = MedicineInstruction(name: item.name, action: item.action, paper: paper, quote: item.quote)
            medicine.alsoKnownAs = item.alsoKnownAs.map { $0.lowercased() }
            medicine.isGroup = item.isGroup
            medicine.startDay = item.startDay
            medicine.endDay = item.endDay
            medicine.strength = item.strength
            medicine.amount = item.amount
            medicine.timesOfDay = item.timesOfDay.sorted()
            medicine.foodNote = item.foodNote
            medicine.onlyIf = item.onlyIf
            medicine.minHoursBetween = item.minHoursBetween
            medicine.maxPerDay = item.maxPerDay
            medicine.reason = item.reason
            medicine.exception = item.exception
            medicine.quotePage = item.quotePage
            medicine.isConfirmed = true
            context.insert(medicine)
            medicine.plan = plan
        }

        for item in draft.rules where item.isConfirmed {
            let rule = CareRule(title: item.title, isAllowed: item.isAllowed, paper: paper, quote: item.quote)
            rule.condition = item.condition
            rule.startDay = item.startDay
            rule.endDay = item.endDay
            rule.quotePage = item.quotePage
            context.insert(rule)
            rule.plan = plan
        }

        for item in draft.tasks where item.isConfirmed {
            let task = CareTask(title: item.title, dueDay: item.dueDay, paper: paper, quote: item.quote)
            task.quotePage = item.quotePage
            context.insert(task)
            task.plan = plan
        }

        for item in draft.appointments where item.isConfirmed {
            let appointment = Appointment(title: item.title, date: item.date, paper: paper, quote: item.quote)
            appointment.doctor = item.doctor
            appointment.place = item.place
            appointment.address = item.address
            appointment.phone = item.phone
            appointment.purpose = item.purpose
            appointment.bring = item.bring
            appointment.quotePage = item.quotePage
            context.insert(appointment)
            appointment.plan = plan
        }

        // goals and contacts aren't instructions so they don't need a tick
        for item in draft.goals {
            let goal = DailyGoal(title: item.title, symbol: item.symbol, target: item.target)
            goal.detail = item.detail
            goal.startDay = item.startDay
            goal.endDay = item.endDay
            goal.quote = item.quote
            context.insert(goal)
            goal.plan = plan
        }

        for item in draft.contacts {
            let contact = CareContact(name: item.name, detail: item.detail, phone: item.phone, role: item.role)
            context.insert(contact)
            contact.plan = plan
        }

        for page in draft.pages {
            let document = SourceDocument(pageNumber: page.pageNumber, paper: paper, redactedText: page.redactedText)
            context.insert(document)
            document.plan = plan
        }

        context.saveNow()
        return plan
    }

    // finalize plan - adds date if needed adds to current or makes a new one
    private static func planToFill(for draft: DraftPlan, in context: ModelContext) -> CarePlan {
        let plan: CarePlan
        if let existing = PlanActions.currentPlan(in: context) {
            plan = existing
        } else {
            plan = CarePlan(procedure: draft.procedure, source: draft.source)
            context.insert(plan)
        }
        if plan.procedure.isEmpty {
            plan.procedure = draft.procedure
        }
        if plan.surgeryDate == nil, let date = draft.surgeryDate {
            plan.surgeryDate = DayMath.calendar.startOfDay(for: date)
        }
        return plan
    }
}
