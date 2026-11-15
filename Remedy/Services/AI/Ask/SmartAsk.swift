//
//  SmartAsk.swift
//  Remedy
//
//  ask answers rules first then the phone ai
//

import Foundation

// ask: rules first, then the phone ai picks a line, never a cloud ai
enum SmartAsk {

    // shown before an ai found answer
    static let closestMatchIntro = "Here\u{2019}s the closest thing on your papers. "

    static func answer(_ question: String, plan: CarePlan, today: Int, now: Date) async -> AskAnswer {
        // 1 the rules
        let ruleAnswer = AskAnswers.answerWithCheck(question, plan: plan, today: today, now: now)
        guard ruleAnswer.kind == .notOnPapers else { return ruleAnswer }

        // 2 the phone's AI one try
        let facts = AskFacts.facts(plan: plan, today: today, now: now)
        guard let pick = await AskPicker.pick(question, facts: facts) else { return ruleAnswer }

        // a symptom the word list missed send them to their surgeon
        if pick.isAboutASymptom {
            return AskAnswers.callSurgeonAnswer(plan)
        }

        // a real line from the papers
        let index = pick.factNumber - 1
        guard facts.indices.contains(index) else { return ruleAnswer }
        let found = facts[index].answer
        return AskAnswer(kind: .fromPapers, text: closestMatchIntro + found.text,
                         quote: found.quote, quoteSource: found.quoteSource, phone: found.phone)
    }
}
