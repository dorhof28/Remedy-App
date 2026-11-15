//
//  TaskEditViewModel.swift
//  Remedy
//
//  add or change one to do, for both looks
//

import Foundation
import Observation
import SwiftData

// the to-do edit form
@MainActor
@Observable
final class TaskEditViewModel {

    var draft: TaskDraft
    var showsProblems = false

    let task: CareTask?
    let plan: CarePlan
    let now: Date

    init(task: CareTask?, plan: CarePlan, now: Date) {
        self.task = task
        self.plan = plan
        self.now = now
        self.draft = task.map { TaskDraft(title: $0.title, dueDay: $0.dueDay) } ?? TaskDraft()
    }

    var isNew: Bool { task == nil }
    var title: String { isNew ? "Add to-do" : "Edit to-do" }
    var saveTitle: String { "Save" }
    let titleLabel = "What to do"
    let titlePrompt = "Like Buy a shower chair"
    let dayTitle = "Due on"
    let deleteTitle = "Delete to-do"
    var problems: [String] { showsProblems && !draft.canSave ? ["Add what to do."] : [] }
    // the sentence under the what to do field
    var titleProblem: String? { problems.first }
    let deleteMessage = "This removes the to-do from your plan."
    var canEditDay: Bool { plan.surgeryDate != nil }

    private var todayDay: Int { DoseSchedule.today(for: plan, now: now) ?? 0 }

    var hasDay: Bool {
        get { draft.dueDay != nil }
        set { draft.dueDay = newValue ? (draft.dueDay ?? todayDay) : nil }
    }

    var dueDate: Date {
        get { plan.surgeryDate.map { DayMath.date(forDay: draft.dueDay ?? todayDay, from: $0) } ?? now }
        set { draft.dueDay = plan.surgeryDate.map { DayMath.dayOffset(of: newValue, from: $0) } }
    }

    // shows the problems instead of saving when the form is not ready
    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard draft.canSave else {
            showsProblems = true
            return false
        }
        TaskActions.save(draft, to: task, in: plan, context: context)
        PlanSync.refresh(plan)
        return true
    }

    func delete(in context: ModelContext) {
        guard let task else { return }
        TaskActions.delete(task, in: context)
        PlanSync.refresh(plan)
    }
}
