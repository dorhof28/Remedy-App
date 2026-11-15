//
//  AskFacts.swift
//  Remedy
//
//  numbered list of everything in the plan for the ask ai
//

import Foundation

// one thing the papers say
struct AskFact {
    // what the AI reads "Medicine Ibuprofen"
    let topic: String
    // what the patient sees if the AI picks it
    let answer: AskAnswer
}

// the short list of plan facts the on-phone ai reads when the rules cannot answer
enum AskFacts {

    // the on-phone AI has a small memory so the list is kept short
    static let maxFacts = 60

    // every fact from the confirmed plan
    static func facts(plan: some PlanFacts, today: Int, now: Date) -> [AskFact] {
        let surgeryDate = plan.surgeryDate ?? now
        var result: [AskFact] = []

        // medicines with the verdict for today
        for medicine in plan.medicines where medicine.isConfirmed {
            let name = MedicineText.fullName(medicine)
            let others = medicine.alsoKnownAs.isEmpty ? "" : " (also called \(medicine.alsoKnownAs.joined(separator: ", ")))"
            let verdict = MedicineMatcher.verdict(for: medicine, today: today, surgeryDate: surgeryDate)
            result.append(AskFact(
                topic: "Medicine: \(name)\(others). \(verdict.headline).",
                answer: AskAnswer(kind: .fromPapers, text: "\(name): \(verdict.headline). \(verdict.sentence)",
                                  quote: medicine.quote,
                                  quoteSource: PlainText.source(paper: medicine.paper, page: medicine.quotePage))))
        }

        // rules
        for rule in plan.rules {
            let status = PlanWording.ruleStatus(rule, today: today, surgeryDate: surgeryDate)
            let condition = rule.condition.isEmpty ? "" : " (\(rule.condition))"
            result.append(AskFact(
                topic: "Instruction: \(rule.title)\(condition). \(status.headline).",
                answer: AskAnswer(kind: .fromPapers, text: status.answer, quote: rule.quote,
                                  quoteSource: PlainText.source(paper: rule.paper, page: rule.quotePage))))
        }

        // visits that haven't happened yet
        let upcoming = plan.appointments
            .filter { DayMath.dayOffset(of: $0.date, from: now) >= 0 }
            .sorted { $0.date < $1.date }
        for visit in upcoming {
            let relative = DayMath.relative(daysFromToday: DayMath.dayOffset(of: visit.date, from: now))
            let place = visit.place.isEmpty ? "" : " at \(visit.place)"
            result.append(AskFact(
                topic: "Visit: \(visit.title). \(relative).",
                answer: AskAnswer(kind: .fromPapers,
                                  text: "\(visit.title) is \(relative): \(DayMath.longDate(visit.date)) at \(DayMath.timeText(of: visit.date))\(place).",
                                  quote: visit.quote,
                                  quoteSource: PlainText.source(paper: visit.paper, page: visit.quotePage))))
        }

        // to-dos not done yet
        for task in plan.tasks where !task.isDone {
            let due = task.dueDay.map { " by \(DayMath.longDate(forDay: $0, from: surgeryDate))" } ?? ""
            result.append(AskFact(
                topic: "To-do: \(task.title).",
                answer: AskAnswer(kind: .fromPapers, text: "Your papers say to do this\(due): \(task.title).",
                                  quote: task.quote,
                                  quoteSource: PlainText.source(paper: task.paper, page: task.quotePage))))
        }

        // phone numbers
        for contact in plan.contacts where !contact.phone.isEmpty {
            let detail = contact.detail.isEmpty ? "" : " (\(contact.detail))"
            result.append(AskFact(
                topic: "Phone number: \(contact.name)\(detail).",
                answer: AskAnswer(kind: .fromPapers,
                                  text: "\(contact.name)\(detail): \(DayMath.phoneText(contact.phone)).")))
        }

        // the surgery itself
        if let date = plan.surgeryDate {
            let what = plan.procedure.isEmpty ? "Your surgery" : "Your \(PlainText.lowerFirst(plan.procedure))"
            result.append(AskFact(
                topic: plan.procedure.isEmpty ? "Surgery date." : "Surgery date: \(plan.procedure).",
                answer: AskAnswer(kind: .fromPapers, text: "\(what) is on \(DayMath.longDate(date)).")))
        }

        return Array(result.prefix(maxFacts))
    }

    // the list as the AI sees it "[1] Medicine " one per line
    static func numberedList(_ facts: [AskFact]) -> String {
        facts.enumerated()
            .map { index, fact in "[\(index + 1)] \(fact.topic)" }
            .joined(separator: "\n")
    }
}
