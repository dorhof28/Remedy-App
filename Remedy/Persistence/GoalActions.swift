//
//  GoalActions.swift
//  Remedy
//
//  saves goal progress
//

import Foundation
import SwiftData

// counts goal progress
enum GoalActions {

    // adds event
    static func addOne(to goal: DailyGoal, now: Date, in context: ModelContext) {
        // insert first then link
        let log = GoalLog(loggedAt: now)
        context.insert(log)
        log.goal = goal
        context.saveNow()
    }

    // undos
    static func removeOne(from goal: DailyGoal, now: Date, in context: ModelContext) {
        let todayStart = DayMath.calendar.startOfDay(for: now)
        let latestToday = goal.logs
            .filter { $0.loggedAt >= todayStart }
            .max { $0.loggedAt < $1.loggedAt }
        guard let latestToday else { return }
        context.delete(latestToday)
        context.saveNow()
    }
}
