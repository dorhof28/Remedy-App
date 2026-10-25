//
//  AskAnswers.swift
//  Remedy
//
//  rule based answers for ask only from the papers
//

import Foundation

// what kind of answer it is
enum AnswerKind: String {
    case fromPapers       // found on the papers
    case notOnPapers      // nothing found: call the care team
    case callSurgeon      // worrying sign: call the surgeon now
    case call911          // emergency
}

// one answer for the chat
struct AskAnswer {
    let kind: AnswerKind
    let text: String
    var quote: String = ""
    var quoteSource: String = ""
    var phone: String = ""          // who the Call button calls ("" = no button)
}

enum AskAnswers {

    // first rule that matches wins
    static func answer(_ question: String, plan: CarePlan, today: Int, now: Date) -> AskAnswer {
        let text = question.lowercased()
        let surgeryDate = plan.surgeryDate ?? now

        // 1 danger words always win even if a medicine is named too
        if contains(text, any: emergencyWords) {
            return AskAnswer(kind: .call911,
                             text: "This could be an emergency. Call 911 now. Don\u{2019}t wait for an answer here.",
                             phone: "911")
        }
        if contains(text, any: warningWords) {
            return callSurgeonAnswer(plan)
        }

        // 2 a medicine
        let medicines = plan.medicines.filter { $0.isConfirmed }
        if let match = MedicineMatcher.matches(inSentence: text, medicines: medicines, today: today).first {
            let medicine = match.medicine
            let verdict = MedicineMatcher.verdict(for: medicine, today: today, surgeryDate: surgeryDate)
            let name = MedicineText.fullName(medicine)
            return AskAnswer(kind: .fromPapers,
                             text: "\(name): \(verdict.headline). \(verdict.sentence)",
                             quote: medicine.quote,
                             quoteSource: PlainText.source(paper: medicine.paper, page: medicine.quotePage))
        }

        // 3 a rule
        let questionWords = stems(of: text)
        if let rule = plan.rules.first(where: { !stems(of: $0.title).isDisjoint(with: questionWords) }) {
            let status = PlanWording.ruleStatus(rule, today: today, surgeryDate: surgeryDate)
            return AskAnswer(kind: .fromPapers, text: status.answer, quote: rule.quote,
                             quoteSource: PlainText.source(paper: rule.paper, page: rule.quotePage))
        }

        // 4 visits
        let upcoming = plan.appointments
            .filter { DayMath.dayOffset(of: $0.date, from: now) >= 0 }
            .sorted { $0.date < $1.date }
        let namedVisit = upcoming.first { !stems(of: $0.title).isDisjoint(with: questionWords) }
        if let visit = namedVisit ?? (contains(text, any: visitWords) ? upcoming.first : nil) {
            let when = "\(DayMath.longDate(visit.date)) at \(DayMath.timeText(of: visit.date))"
            let place = visit.place.isEmpty ? "" : " at \(visit.place)"
            let relative = DayMath.relative(daysFromToday: DayMath.dayOffset(of: visit.date, from: now))
            return AskAnswer(kind: .fromPapers,
                             text: "\(visit.title) is \(relative): \(when)\(place).",
                             quote: visit.quote,
                             quoteSource: PlainText.source(paper: visit.paper, page: visit.quotePage))
        }

        // 5 what to take today
        if contains(text, any: todayWords) {
            let active = medicines.filter { $0.action == .take && DoseSchedule.isActive($0, on: today) }
            if active.isEmpty {
                return AskAnswer(kind: .fromPapers, text: "Your papers don\u{2019}t list any every-day medicines for today.")
            }
            let lines = active.map { "\(MedicineText.fullName($0)) at \(MedicineText.timesText($0))" }
            return AskAnswer(kind: .fromPapers, text: "Today: \(PlainText.list(lines)).")
        }

        // 6 not on the papers say so and say who to call
        return AskAnswer(kind: .notOnPapers,
                         text: "I couldn\u{2019}t find that on your papers, so I won\u{2019}t guess. Your surgeon\u{2019}s office can answer it.",
                         phone: surgeonPhone(plan))
    }

    // call your surgeon answer - also used when the ai spots a symptom
    static func callSurgeonAnswer(_ plan: CarePlan) -> AskAnswer {
        AskAnswer(kind: .callSurgeon,
                  text: "This can be a sign of a problem after surgery. Call your surgeon\u{2019}s office now. If it feels serious, call 911.",
                  phone: surgeonPhone(plan))
    }

    // MARK: - Word lists (to be checked by our doctor reviewer)

    // call 911
    static let emergencyWords = [
        "chest pain", "can't breathe", "cant breathe", "cannot breathe", "short of breath",
        "trouble breathing", "passed out", "fainted", "unconscious", "stroke", "face droop", "seizure",
    ]

    // call the surgeon now
    static let warningWords = [
        "fever", "bleeding", "pus", "red and hot", "swollen", "swelling", "calf",
        "throwing up", "vomit", "can't pee", "wound opened", "stitches came", "numb",
    ]

    static let visitWords = ["appointment", "visit", "check-up", "checkup", "see the doctor", "see my doctor"]
    static let todayWords = ["today", "what do i take", "which pills", "my pills", "my medicine"]

    // MARK: - Helpers

    private static func contains(_ text: String, any words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }

    // the surgeon's office number or the first care-team number
    private static func surgeonPhone(_ plan: CarePlan) -> String {
        plan.contacts.first { $0.role == .careTeam }?.phone ?? ""
    }

    // word roots so driving and drives both become driv
    static func stems(of text: String) -> Set<String> {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        var result: Set<String> = []
        for word in words where word.count >= 4 && !skipWords.contains(word) {
            var stem = word
            for ending in ["ing", "s", "e"] where stem.hasSuffix(ending) && stem.count - ending.count >= 4 {
                stem = String(stem.dropLast(ending.count))
            }
            result.insert(stem)
        }
        return result
    }

    private static let skipWords: Set<String> = [
        "what", "when", "where", "which", "will", "with", "your", "from", "that", "this",
        "have", "does", "still", "after", "before", "surgery", "allowed", "okay", "take", "today",
    ]
}
