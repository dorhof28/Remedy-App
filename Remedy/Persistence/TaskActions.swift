//
//  TaskActions.swift
//  Remedy
//
//  saves to do items
//

import Foundation
import SwiftData

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
}
