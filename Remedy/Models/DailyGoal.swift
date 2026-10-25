//
//  DailyGoal.swift
//  Remedy
//
//  a daily goal like walking
//

import Foundation
import SwiftData

@Model
final class DailyGoal {

    var title: String = ""
    var detail: String = ""
    var symbol: String = "checkmark.circle"

    // how many times a day
    var target: Int = 1

    var startDay: Int?
    var endDay: Int?
    // where it came from
    var quote: String = ""

    // the plan it belongs to
    var plan: CarePlan?

    
    @Relationship(deleteRule: .cascade, inverse: \GoalLog.goal)
    var logs: [GoalLog] = []

    init(title: String, symbol: String, target: Int) {
        self.title = title
        self.symbol = symbol
        self.target = target
    }
}

// one time a goal was done
@Model
final class GoalLog {

    var loggedAt: Date = Date()

    // which goal
    var goal: DailyGoal?

    init(loggedAt: Date = Date()) {
        self.loggedAt = loggedAt
    }
}
