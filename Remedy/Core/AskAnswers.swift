//
//  AskAnswers.swift
//  Remedy
//
//  word based answers for ask only from the papers
//

import Foundation

// what kind of answer it is
enum AnswerKind: String {
    case fromPapers       // found on the papers
    case notOnPapers      // nothing found: call the care team
    case callSurgeon      // worrying sign: call the surgeon now
    case call911          // emergency
    case whichOne         // more than one medicine named: the patient picks one
}

// one answer for the chat
struct AskAnswer {
    let kind: AnswerKind
    var text: String
    var quote: String = ""
    var quoteSource: String = ""
    var phone: String = ""          // who the Call button calls ("" = no button)
    var choices: [String] = []      // whichOne: the medicine names to tap
}

// answers ask questions with word rules, only from the papers, never a guess
enum AskAnswers {

    // first rule that matches wins
    // the check for a medicine: its words and the line the app follows
    // no words means answer from the followed line alone
    typealias PaperCheckLookup<Medicine> = (Medicine, Date) -> (check: CheckMessage?, followed: Medicine?)?

    // the answer with repeated lines removed
    static func answer<Plan: PlanFacts>(_ question: String, plan: Plan, today: Int, now: Date,
                                        paperCheck: PaperCheckLookup<Plan.Medicine>) -> AskAnswer {
        tidy(rawAnswer(question, plan: plan, today: today, now: now, paperCheck: paperCheck))
    }

    // tries each rule in order: danger words, a medicine, an instruction, visits, today, then not on the papers
    private static func rawAnswer<Plan: PlanFacts>(_ question: String, plan: Plan, today: Int, now: Date,
                                                   paperCheck: PaperCheckLookup<Plan.Medicine>) -> AskAnswer {
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
        let matches = MedicineMatcher.matches(inSentence: text, medicines: medicines, today: today)
        // two different medicines: ask which one instead of answering only the first
        var named: [Plan.Medicine] = []
        for match in matches where !named.contains(where: { sameMedicine($0, match.medicine) }) {
            named.append(match.medicine)
        }
        if named.count > 1 {
            let names = named.map(\.name)
            let list = names.dropLast().joined(separator: ", ") + " or " + (names.last ?? "")
            return AskAnswer(kind: .whichOne, text: "Which one do you mean: \(list)?", choices: names)
        }
        if let match = matches.first {
            let medicine = match.medicine

            // two or more papers about it: say so, show them all, answer from the one the app follows
            let lookup = paperCheck(medicine, surgeryDate)
            if let lookup, let check = lookup.check {
                let followedLine = lookup.followed
                // an open circle follows no paper so there is no answer to give
                let verdict = followedLine.map { line in
                    let verdict = MedicineMatcher.verdict(for: line, today: today, surgeryDate: surgeryDate)
                    return "\(MedicineText.fullName(line)): \(verdict.headline). \(verdict.sentence)"
                }
                let parts = [check.headline + ".", check.detail, verdict ?? ""]
                return AskAnswer(kind: .fromPapers,
                                 text: parts.filter { !$0.isEmpty }.joined(separator: " "),
                                 quote: check.quotes.map { "\($0.doctor): \u{201C}\($0.text)\u{201D}" }.joined(separator: "\n"),
                                 quoteSource: check.quotes.count == 2 ? "Both papers" : "Your papers")
            }

            // the line the app follows, which may be another paper's line for the same medicine
            let line = lookup?.followed ?? medicine
            let verdict = MedicineMatcher.verdict(for: line, today: today, surgeryDate: surgeryDate)
            let name = MedicineText.fullName(line)
            return AskAnswer(kind: .fromPapers,
                             text: "\(name): \(verdict.headline). \(verdict.sentence)",
                             quote: line.quote,
                             quoteSource: PlainText.source(paper: line.paper, page: line.quotePage))
        }

        // 3 an instruction
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
    static func callSurgeonAnswer(_ plan: some PlanFacts) -> AskAnswer {
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

    // MARK: - No repeats

    // the answer without repeated sentences or a quote that only says the answer again
    static func tidy(_ answer: AskAnswer) -> AskAnswer {
        var result = answer
        result.text = dedupedSentences(answer.text)
        let quoteLines = uniqueLines(answer.quote)
        // a quote the answer already says word for word is cited once, in the answer
        let said = squash(result.text)
        let fresh = quoteLines.filter { !said.contains(squash(stripSpeaker($0))) }
        result.quote = fresh.joined(separator: "\n")
        if fresh.isEmpty { result.quoteSource = "" }
        return result
    }

    // drops a sentence that says the same as an earlier one or is inside it
    static func dedupedSentences(_ text: String) -> String {
        var kept: [String] = []
        for sentence in splitSentences(text) {
            let key = squash(sentence)
            if key.isEmpty { continue }
            if kept.contains(where: { squash($0).contains(key) }) { continue }
            // a later longer sentence replaces a short one it contains
            kept.removeAll { squash(sentence).contains(squash($0)) }
            kept.append(sentence)
        }
        return kept.joined(separator: " ")
    }

    // a reply that would match the one before it word for word gets a short pointer instead
    static func avoidingRepeat(_ answer: AskAnswer, previous: String?) -> AskAnswer {
        guard let previous, squash(previous) == squash(answer.text) else { return answer }
        var result = answer
        let first = splitSentences(answer.text).first ?? answer.text
        result.text = "Same as my last answer: \(PlainText.lowerFirst(first))"
        result.quote = ""
        result.quoteSource = ""
        return result
    }

    // splits on sentence ends but keeps decimals like 2.5 together
    private static func splitSentences(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?".contains(character) {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { parts.append(rest) }
        return parts
    }

    // a quote's lines without repeats, compared without spaces or case
    private static func uniqueLines(_ quote: String) -> [String] {
        var seen: Set<String> = []
        return quote.split(separator: "\n").map(String.init).filter { seen.insert(squash($0)).inserted }
    }

    // "Dr Rao: \u{201C}text\u{201D}" becomes the text
    private static func stripSpeaker(_ line: String) -> String {
        guard let open = line.firstIndex(of: "\u{201C}") else { return line }
        return String(line[open...])
    }

    // letters and digits only so spacing and punctuation never hide a repeat
    private static func squash(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    // MARK: - Helpers

    private static func contains(_ text: String, any words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }

    // true when both names point to the same medicine, brand or generic
    private static func sameMedicine<Medicine: MedicineFacts>(_ first: Medicine, _ second: Medicine) -> Bool {
        MedicineIdentity.same(MedicineIdentity.names(first.name, alsoKnownAs: first.alsoKnownAs),
                              MedicineIdentity.names(second.name, alsoKnownAs: second.alsoKnownAs))
    }

    // the surgeon's office number or the first care-team number
    static func surgeonPhone(_ plan: some PlanFacts) -> String {
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
