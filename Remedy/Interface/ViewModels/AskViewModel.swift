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

    var id: PersistentIdentifier { message.persistentModelID }
    var showsQuote: Bool { !quote.isEmpty }
    var showsCall: Bool { callURL != nil && !callTitle.isEmpty }
}

// MARK: - ViewModel

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
    let introTitle = "Ask about your papers"
    let introDetail = "I only answer from your own papers, and I show you the line each answer came from. If it isn\u{2019}t on your papers, I\u{2019}ll tell you who to call."
    let prompt = "Type a question"
    let sendLabel = "Send"
    let clearTitle = "Clear chat"
    let clearMessage = "This deletes the questions and answers on this phone. Your plan stays."
    let footnote = "Not for emergencies. If something feels wrong, call 911."
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
        let medicines = plan.medicines.filter { $0.isConfirmed }

        // a medicine they must stop or avoid by the name on the box
        if let stop = medicines.first(where: { $0.action == .stop }) {
            let name = stop.alsoKnownAs.first.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? stop.name
            result.append("Can I take \(name)?")
        }
        // a rule
        if let rule = plan.rules.first {
            result.append("Can I \(ruleVerb(rule.title))?")
        }
        // the next visit
        if plan.appointments.contains(where: { DayMath.dayOffset(of: $0.date, from: now) >= 0 }) {
            result.append("When is my next appointment?")
        }
        // today's pills
        if medicines.contains(where: { $0.action == .take && DoseSchedule.isActive($0, on: day) }) {
            result.append("What do I take today?")
        }
        return result
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
                           callURL: phone.isEmpty ? nil : DayMath.phoneURL(phone))
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
        ChatActions.addAnswer(answer, in: context)
    }

    // deletes the chat
    func clear(in context: ModelContext) {
        ChatActions.deleteAll(in: context)
    }

    // MARK: - Private

    private func tone(for kind: AnswerKind) -> Tone {
        switch kind {
        case .fromPapers: return .neutral
        case .notOnPapers: return .info
        case .callSurgeon: return .caution
        case .call911: return .stop
        }
    }

    private func symbol(for kind: AnswerKind) -> String {
        switch kind {
        case .fromPapers: return ""
        case .notOnPapers: return "questionmark.circle.fill"
        case .callSurgeon: return "exclamationmark.triangle.fill"
        case .call911: return "cross.case.fill"
        }
    }

    private func callTitle(for kind: AnswerKind, phone: String) -> String {
        if phone.isEmpty { return "" }
        if kind == .call911 { return "Call 911" }
        return "Call your surgeon\u{2019}s office"
    }

    private func ruleVerb(_ title: String) -> String {
        var words = title.lowercased()
        if words.hasPrefix("no ") { words.removeFirst(3) }
        if words.hasSuffix("ing") { words = String(words.dropLast(3)) + "e" }
        if words.hasSuffix("s") { words.removeLast() }
        return words
    }
}
