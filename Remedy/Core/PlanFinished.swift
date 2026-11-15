//
//  PlanFinished.swift
//  Remedy
//
//  when every medicine rule and goal from the papers has ended
//

import Foundation

// true once every medicine, rule, visit and to-do has ended
nonisolated enum PlanFinished {

    // end days of everything that can end, nil means it never ends
    // stopped medicines are left out by the caller, they wait for the doctor
    static func isFinished(endDays: [Int?], day: Int) -> Bool {
        guard !endDays.isEmpty else { return false }
        return endDays.allSatisfy { end in
            guard let end else { return false }
            return end < day
        }
    }
}
