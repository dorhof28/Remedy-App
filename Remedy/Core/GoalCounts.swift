//
//  GoalCounts.swift
//  Remedy
//
//  count rules for daily goals like "10 heel slides, 3 times a day"
//

import Foundation

// how many times a daily goal is done and when it counts as complete
nonisolated enum GoalCounts {

    // how many times to do it today
    static func dailyTarget(timesPerDay: Int?, target: Int) -> Int {
        max(1, timesPerDay ?? target)
    }

    // done so far never shows above the target
    static func shownCount(done: Int, target: Int) -> Int {
        max(0, min(done, target))
    }

    static func isComplete(done: Int, target: Int) -> Bool {
        done >= target
    }

    // "2 of 3"
    static func countText(done: Int, target: Int) -> String {
        "\(shownCount(done: done, target: target)) of \(target)"
    }

    // "10 reps" or "3 sets of 10 reps" or "hold 30 seconds"
    static func amountText(reps: Int?, sets: Int?, seconds: Int?) -> String {
        var parts: [String] = []
        if let reps, reps > 0 {
            if let sets, sets > 1 {
                parts.append("\(sets) sets of \(PlainText.count(reps, "rep"))")
            } else {
                parts.append(PlainText.count(reps, "rep"))
            }
        } else if let sets, sets > 1 {
            parts.append("\(sets) sets")
        }
        if let seconds, seconds > 0 {
            parts.append(reps == nil ? "hold \(PlainText.count(seconds, "second"))" : "\(PlainText.count(seconds, "second")) each")
        }
        return parts.joined(separator: ", ")
    }

    // "Done one" button label with the count left
    static func buttonText(done: Int, target: Int) -> String {
        done >= target ? "Done one more" : "Done one"
    }
}
