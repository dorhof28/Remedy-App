//
//  PlanWording.swift
//  Remedy
//
//  rule wording so it reads the same everywhere
//

import Foundation

// today rules status
enum RuleStatusKind: Equatable {
    case notAllowed         // no
    case allowed            // yes
    case allowedLater       // its allowed but the rule starts later
    case notAllowedLater    // a "don't" that starts later ( nothing to eat after midnight)
    case ended              //  rule is over
}

// words storage
struct RuleStatus {
    let kind: RuleStatusKind
    let headline: String    // "Not yet" / "OK" / "From Sun, Nov 1"
    let detail: String      // "Until Thu, Nov 12" / "Keep the dressing dry"
    let answer: String      // a full sentence for Ask
}

enum PlanWording {

    // rule status for today
    static func ruleStatus(_ rule: CareRule, today: Int, surgeryDate: Date) -> RuleStatus {
        let start = DoseSchedule.startDay(of: rule)
        let end = rule.endDay ?? Int.max

        if today > end {
            let endText = DayMath.shortDate(forDay: end, from: surgeryDate)
            return RuleStatus(kind: .ended, headline: "Over", detail: "Ended \(endText)",
                                  answer: "That rule on your papers ended on \(endText).")
        }

        if today < start {
            let startText = DayMath.shortDate(forDay: start, from: surgeryDate)
            let when = "\(DayMath.longDate(forDay: start, from: surgeryDate)) (\(DayMath.surgeryWords(forDay: start)))"
            let relative = DayMath.relative(daysFromToday: start - today)
            if rule.isAllowed {
                return RuleStatus(kind: .allowedLater, headline: "From \(startText)", detail: relative,
                                      answer: "Not yet. Your papers say you can from \(when), \(relative).")
            }
            return RuleStatus(kind: .notAllowedLater, headline: "Starts \(startText)", detail: relative,
                                  answer: "Your papers say: \(PlainText.lowerFirst(rule.title)), starting \(when).")
        }

        if rule.isAllowed {
            let detail = rule.condition.isEmpty ? "OK now" : rule.condition
            let extra = rule.condition.isEmpty ? "" : " \(rule.condition)."
            return RuleStatus(kind: .allowed, headline: "OK", detail: detail,
                                  answer: "Yes, that’s OK now.\(extra)")
        }
        let until: String
        if rule.endDay != nil {
            until = "Until \(DayMath.shortDate(forDay: end, from: surgeryDate))"
        } else if !rule.condition.isEmpty {
            until = rule.condition
        } else {
            until = "Until your surgeon says it’s OK"
        }
        return RuleStatus(kind: .notAllowed, headline: "Not yet", detail: until,
                              answer: "Not yet. Your papers say: \(PlainText.lowerFirst(rule.title)). \(until).")
    }

    // for tasks
    static func taskDueText(_ task: CareTask, today: Int, surgeryDate: Date) -> String {
        if task.isDone {
            if let doneAt = task.doneAt { return "Done at \(DayMath.timeText(of: doneAt))" }
            return "Done"
        }
        guard let due = task.dueDay else { return "Any time" }
        if due == today { return "Due today" }
        let date = DayMath.shortDate(forDay: due, from: surgeryDate)
        if due < today { return "Was due \(date)" }
        if due == 0 { return "Due \(date) · surgery day" }
        return "Due \(date) · \(DayMath.relative(daysFromToday: due - today))"
    }

    // is the task for today
    static func isOnToday(_ task: CareTask, today: Int) -> Bool {
        guard !task.isDone, let due = task.dueDay else { return false }
        if due == today { return true }
        let paperNow: PaperKind = today >= 1 ? .afterSurgery : .beforeSurgery
        return due < today && task.paper == paperNow
    }
}
