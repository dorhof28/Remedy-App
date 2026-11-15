//
//  RuleReminders.swift
//  Remedy
//
//  splits a long rule into short reminders like "Do not eat after midnight" and "Clear liquids are allowed until 2 hours before"
//  each one is marked don't, must do or allowed by plain words, the paper quote is never changed
//

import Foundation

// splits a rule's words into short do, don't and may reminders
nonisolated enum RuleReminders {

    enum Kind: String, CaseIterable, Sendable {
        case dont, must, may

        var title: String {
            switch self {
            case .dont: return "Avoid"
            case .must: return "Do"
            case .may: return "Fine"
            }
        }

        var symbol: String {
            switch self {
            case .dont: return "xmark.circle.fill"
            case .must: return "exclamationmark.circle.fill"
            case .may: return "checkmark.circle.fill"
            }
        }
    }

    // one short reminder line
    struct Reminder: Equatable, Sendable {
        let text: String
        let kind: Kind
    }

    // one rule as short reminders in the order the paper gives them
    // isAllowed is only used when the words give no hint
    static func split(_ text: String, isAllowed: Bool) -> [Reminder] {
        let parts = sentences(of: text)
        guard !parts.isEmpty else { return [] }
        return parts.map { Reminder(text: $0, kind: kind(of: $0) ?? (isAllowed ? .may : .dont)) }
    }

    // sentences and parts after a semicolon or "then", with the end mark taken off
    static func sentences(of text: String) -> [String] {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        var parts: [String] = []
        var current = ""
        let characters = Array(flat)
        for (index, character) in characters.enumerated() {
            let next = index + 1 < characters.count ? characters[index + 1] : " "
            let previous = index > 0 ? characters[index - 1] : " "
            // a dot inside a number like 0.5 or a word like e.g. is not an end
            let ends = (character == "." && next == " " && !previous.isNumber && !isShortForm(current))
                || character == ";" || character == "!"
            if ends {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts
            .flatMap(splitThen)
            .map(tidy)
            .filter { $0.split(separator: " ").count >= 2 }
    }

    // MARK: - Words

    private static let keepGoing = ["do not stop", "don't stop", "don\u{2019}t stop", "do not skip", "don't skip",
                                    "don\u{2019}t skip", "do not miss", "do not delay", "keep taking", "continue"]
    private static let dontWords = ["do not", "don't", "don\u{2019}t", "never", "avoid", "no ", "nothing",
                                    "not allowed", "must not", "should not", "shouldn't", "stop "]
    private static let mayWords = ["allowed", "you may", "may ", "you can", "can ", "okay", "ok to", "it is fine",
                                   "is fine", "permitted"]
    // words that mean must anywhere in the line
    private static let mustWords = ["must", "need to", "needs to", "should", "make sure", "remember", "be sure"]
    // a line that starts with one of these is an order, like "Bring your pill bottle"
    private static let mustStarts = ["bring", "shower", "wash", "wear", "take", "call", "arrive", "keep", "check",
                                     "tell", "have", "use", "walk", "drink", "eat", "follow", "go", "get", "plan",
                                     "please"]

    // nil when the words give no hint
    static func kind(of sentence: String) -> Kind? {
        let lower = " " + sentence.lowercased()
        if keepGoing.contains(where: lower.contains) { return .must }
        if dontWords.contains(where: { lower.contains(" " + $0) }) { return .dont }
        if mayWords.contains(where: { lower.contains(" " + $0) }) { return .may }
        if mustWords.contains(where: { lower.contains(" " + $0) }) { return .must }
        let first = lower.split(separator: " ").first.map(String.init) ?? ""
        if mustStarts.contains(first) { return .must }
        return nil
    }

    // MARK: - Helpers

    // "until 2 hours before; then nothing by mouth" splits at then
    private static func splitThen(_ part: String) -> [String] {
        let pieces = part.components(separatedBy: ", then ").flatMap { $0.components(separatedBy: " then, ") }
        return pieces.enumerated().map { $0.offset == 0 ? $0.element : "Then " + $0.element }
    }

    // trims punctuation and a leading then
    private static func tidy(_ part: String) -> String {
        var text = part.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.:-")))
        if text.lowercased().hasPrefix("then ") { text = String(text.dropFirst(5)) }
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    // a period after a short form like dr or e.g does not end the sentence
    private static func isShortForm(_ text: String) -> Bool {
        let last = text.split(separator: " ").last.map { $0.lowercased() } ?? ""
        return ["e.g", "i.e", "dr", "mr", "mrs", "ms", "approx", "vs", "st"].contains(last)
            || (last.count == 1 && last.first?.isLetter == true)
    }
}
