//
//  DoseSchedule+Models.swift
//  Remedy
//
//  dose rules for the saved models
//

import Foundation
import SwiftData

// one dose time for one saved medicine
typealias DoseSlot = DoseSlotOf<MedicineInstruction>

// saved lines another paper replaced
typealias SkippedLines = SkippedLinesOf<PersistentIdentifier>

extension DoseSchedule {

    // for recovery period
    static func isActive(_ goal: DailyGoal, on day: Int) -> Bool {
        isGoalActive(startDay: goal.startDay, endDay: goal.endDay, on: day)
    }

    // for daily goals
    static func goalCount(_ goal: DailyGoal, now: Date) -> Int {
        goalCount(loggedAt: goal.logs.map(\.loggedAt), now: now)
    }
}
