//
//  PaperActions.swift
//  Remedy
//
//  removing one set of papers
//

import Foundation
import SwiftData

// removes one set of papers and the items only it gave
enum PaperActions {

    // how many items came only from this paper
    static func itemCount(of paper: Paper, in plan: CarePlan) -> Int {
        let id = paper.id
        return plan.medicines.filter { $0.paperID == id }.count
            + plan.tasks.filter { $0.paperID == id }.count
            + plan.rules.filter { $0.paperID == id }.count
            + plan.appointments.filter { $0.paperID == id }.count
    }

    // deletes the paper, its pages and what was read from it
    static func remove(_ paper: Paper, from plan: CarePlan, in context: ModelContext) {
        let id = paper.id
        plan.medicines.filter { $0.paperID == id }.forEach { context.delete($0) }
        plan.tasks.filter { $0.paperID == id }.forEach { context.delete($0) }
        plan.rules.filter { $0.paperID == id }.forEach { context.delete($0) }
        plan.appointments.filter { $0.paperID == id }.forEach { context.delete($0) }
        plan.documents.filter { $0.paperID == id }.forEach { context.delete($0) }
        context.delete(paper)
        context.saveNow()
    }
}
