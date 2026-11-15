//
//  AskViewModel.swift
//  Remedy
//
//  ask tab for both looks
//

import Foundation
import SwiftData

// MARK: - Display data

// one bubble
struct ChatRow: Identifiable {
    let message: ChatMessage
    let isFromPatient: Bool
    let text: String
    let quote: String
    let quoteSource: String
    let tone: Tone
    let symbol: String              // icon on answers ("" = none)
    let callTitle: String           // "" = no Call button
    let callURL: URL?
    // which medicine they mean, each one asks again by its name
    var choices: [String] = []

    var id: PersistentIdentifier { message.persistentModelID }
    var showsQuote: Bool { !quote.isEmpty }
    var showsCall: Bool { callURL != nil && !callTitle.isEmpty }
}

// MARK: - ViewModel

// the ask screen: suggested questions and the chat as rows, shared by both looks
struct AskViewModel {

    let plan: CarePlan?
    let messages: [ChatMessage]     // oldest first
    let now: Date
    let day: Int

    init(plan: CarePlan?, messages: [ChatMessage], now: Date) {
        self.plan = plan
        self.messages = messages
        self.now = now
        self.day = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
    }

    // MARK: - Words

    let title = "Ask"
    let emptyTitle = "No plan yet"
    let emptyDetail = "Scan your papers first. Then you can ask questions about them here."
    let prompt = "Type a question"
    let sendLabel = "Send"
    let clearMessage = "This deletes the questions and answers on this phone. Your plan stays."
    let footnote = "Not for emergencies. If something feels wrong, call 911."
    // simple look, right under the box
    let emergencyLinkTitle = "Emergency? Call 911"
    let emergencyURL = DayMath.phoneURL("911")
    let thinkingText = "Looking through your papers\u{2026}"

    var hasPlan: Bool { plan != nil }
    var showsIntro: Bool { messages.isEmpty }
    var canClear: Bool { !messages.isEmpty }

    // send only works when something is typed
    func canSend(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Suggestions (built from THIS plan, so every one has an answer)

    var suggestions: [String] {
        guard let plan else { return [] }
        var result: [String] = []
        // sorted so the same questions show every time
        let medicines = plan.medicines.filter { $0.isConfirmed }.sorted { $0.name < $1.name }

        // a medicine they must stop or avoid by the name on the box, never a group like any other nsaid
        if let stop = medicines.first(where: { $0.action == .stop && !$0.isGroup }) {
            result.append("Can I take \(boxName(stop))?")
        }
        // today's pills
        if medicines.contains(where: { $0.action == .take && DoseSchedule.isActive($0, on: day) }) {
            result.append("What do I take today?")
        }
        // a rule, asked the way a patient would
        if let rule = plan.rules.first(where: { ruleQuestion($0.title) != nil }), let question = ruleQuestion(rule.title) {
            result.append(question)
        }
        // the next visit
        if plan.appointments.contains(where: { DayMath.dayOffset(of: $0.date, from: now) >= 0 }) {
            result.append("When is my next appointment?")
        }
        // a medicine they can keep taking
        if let keep = medicines.first(where: { $0.action == .okToTake && !$0.isGroup }) {
            result.append("Can I keep taking \(boxName(keep))?")
        }
        // a second stop medicine so there is always something to try
        let stops = medicines.filter { $0.action == .stop && !$0.isGroup }
        if result.count < 3, stops.count > 1 {
            let question = "Can I take \(boxName(stops[1]))?"
            if !result.contains(question) { result.append(question) }
        }
        return Array(result.prefix(4))
    }

    // MARK: - Bubbles

    var rows: [ChatRow] {
        messages.map { message in
            if message.isFromPatient {
                return ChatRow(message: message, isFromPatient: true, text: message.text, quote: "", quoteSource: "",
                               tone: .info, symbol: "", callTitle: "", callURL: nil)
            }
            let kind = AnswerKind(rawValue: message.kindRaw) ?? .fromPapers
            let phone = message.callPhone
            return ChatRow(message: message, isFromPatient: false, text: message.text,
                           quote: message.quote, quoteSource: message.quoteSource,
                           tone: tone(for: kind), symbol: symbol(for: kind),
                           callTitle: callTitle(for: kind, phone: phone),
                           callURL: phone.isEmpty ? nil : DayMath.phoneURL(phone), choices: message.choices)
        }
    }

    // the newest answer and the question before it
    var lastAnswer: ChatRow? { rows.last { !$0.isFromPatient } }
    var lastQuestion: ChatRow? { rows.last { $0.isFromPatient } }

    // the newest bubble so the screen can scroll to it
    var lastRowID: PersistentIdentifier? { messages.last?.persistentModelID }

    // MARK: - Actions

    // sending is 3 steps so the question shows right away

    // 1 saves the question
    func saveQuestion(_ text: String, in context: ModelContext) -> String? {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard plan != nil, !question.isEmpty else { return nil }
        ChatActions.add(question, isFromPatient: true, in: context)
        return question
    }

    // 2 finds the answer word rules first then the phone's AI
    func findAnswer(to question: String) async -> AskAnswer? {
        guard let plan else { return nil }
        return await SmartAsk.answer(question, plan: plan, today: day, now: now)
    }

    // 3 saves the answer
    func saveAnswer(_ answer: AskAnswer, in context: ModelContext) {
        let previous = messages.last { !$0.isFromPatient }?.text
        ChatActions.addAnswer(AskAnswers.avoidingRepeat(answer, previous: previous), in: context)
    }

    // deletes the chat
    func clear(in context: ModelContext) {
        ChatActions.deleteAll(in: context)
    }

    // MARK: - Private

    // the bubble color for each kind of answer
    private func tone(for kind: AnswerKind) -> Tone {
        switch kind {
        case .fromPapers: return .neutral
        case .notOnPapers: return .info
        case .callSurgeon: return .caution
        case .call911: return .stop
        case .whichOne: return .info
        }
    }

    private func symbol(for kind: AnswerKind) -> String {
        switch kind {
        case .fromPapers: return ""
        case .notOnPapers: return "questionmark.circle.fill"
        case .callSurgeon: return "exclamationmark.triangle.fill"
        case .call911: return "cross.case.fill"
        case .whichOne: return "questionmark.bubble.fill"
        }
    }

    // the call button under an answer, empty when there is no number
    private func callTitle(for kind: AnswerKind, phone: String) -> String {
        if phone.isEmpty { return "" }
        if kind == .call911 { return "Call 911" }
        return "Call your surgeon\u{2019}s office"
    }

    // a rule asked the way a patient would, nil when it would read oddly
    // "Nothing to eat after midnight" "Can I eat after midnight?"
    // "No driving" "When can I start driving?"  "No alcohol" "Can I have alcohol?"
    func ruleQuestion(_ title: String) -> String? {
        let words = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if words.hasPrefix("nothing to ") {
            let rest = words.dropFirst("nothing to ".count)
            return rest.isEmpty ? nil : "Can I \(rest)?"
        }
        guard words.hasPrefix("no ") else { return nil }
        let rest = String(words.dropFirst(3))
        guard !rest.isEmpty else { return nil }
        let isDoing = rest.split(separator: " ").contains { $0.hasSuffix("ing") }
        return isDoing ? "When can I start \(rest)?" : "Can I have \(rest)?"
    }

    // the everyday name on the box, "Advil" for ibuprofen
    private func boxName(_ medicine: MedicineInstruction) -> String {
        let own = medicine.name.lowercased()
        let brand = medicine.alsoKnownAs.first { !$0.isEmpty && $0.lowercased() != own }
        let name = brand ?? medicine.name
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

// MARK: - Redesigned ask (screens 52 to 54)

extension AskViewModel {
    static let heroTitle = "Ask About Your Papers"
    static let heroText = "Answers come only from your papers, with the exact words shown."
    static let clearChatTitle = "Clear Chat"
    static let callOfficeTitle = "Call Your Doctor\u{2019}s Office"
    static let callSurgeonTitle = "Call Surgeon\u{2019}s Office"
    static let emergencyEyebrow = "This could be an emergency"
    static let emergencyHeading = "Call 911 now."
    static let notSentFootnote = "Remedy did not send this question to the AI."
    static let readAloudTitle = "Read Aloud"
    static let examplesTitle = "For example"

    // the plain reason under "Call 911 now." from the question's own words
    static func emergencyText(question: String) -> String {
        let words = question.lowercased()
        if words.contains("chest") || words.contains("breath") {
            return "Chest pain or trouble breathing after surgery needs help right away."
        }
        if words.contains("bleed") || words.contains("blood") { return "Heavy bleeding after surgery needs help right away." }
        return "This needs help right away."
    }

    // the question asked just before an answer
    func question(before row: ChatRow) -> String {
        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return "" }
        return rows[..<index].last { $0.isFromPatient }?.text ?? ""
    }

    // the surgeon's office for the 911 card's second button
    var surgeonURL: URL? {
        guard let plan else { return nil }
        let phone = AskAnswers.surgeonPhone(plan)
        return phone.isEmpty ? nil : DayMath.phoneURL(phone)
    }

    // "Page 3" over a quote
    static func pageSource(_ source: String) -> String {
        guard let range = source.range(of: "page ", options: .caseInsensitive) else { return source }
        return "Page " + source[range.upperBound...]
    }

    // the example questions, written the way the design does
    var examples: [String] {
        let fixed = ["Can I take Advil?", "When can I shower?", "What do I take tonight?", "When can I drive?"]
        return suggestions.isEmpty ? fixed : suggestions
    }
}
