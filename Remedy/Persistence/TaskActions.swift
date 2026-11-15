//
//  TaskActions.swift
//  Remedy
//
//  saves to do items
//

import Foundation
import SwiftData

// saves to-do changes
enum TaskActions {

    // marks done or not done
    static func setDone(_ isDone: Bool, for task: CareTask, now: Date, in context: ModelContext) {
        task.isDone = isDone
        task.doneAt = isDone ? now : nil
        context.saveNow()
    }

    // flips done
    static func toggle(_ task: CareTask, now: Date, in context: ModelContext) {
        setDone(!task.isDone, for: task, now: now, in: context)
    }

    // adds or changes a to do
    @discardableResult
    static func save(_ draft: TaskDraft, to task: CareTask?, in plan: CarePlan, context: ModelContext) -> CareTask? {
        guard draft.canSave else { return nil }
        let target: CareTask
        if let task {
            target = task
        } else {
            target = CareTask(title: draft.trimmedTitle, dueDay: draft.dueDay, paper: .afterSurgery, quote: "")
            context.insert(target)
            target.plan = plan
        }
        target.title = draft.trimmedTitle
        target.dueDay = draft.dueDay
        context.saveNow()
        return target
    }

    static func delete(_ task: CareTask, in context: ModelContext) {
        context.delete(task)
        context.saveNow()
    }
}
