//
//  ExplainViewModel.swift
//  Remedy
//
//  "Explain this" on a red card, both looks
//

import Foundation
import Observation

// the explain this button on a red card, the phone ai rewords the quotes only
@MainActor
@Observable
final class ExplainViewModel {

    static let buttonTitle = "Explain this"
    // the label over the phone's words, it never picks a side
    static let label = "Simpler words, not advice"
    static let workingText = "Writing it in simple words\u{2026}"
    static let note = "Written by the phone\u{2019}s AI to help you understand. It does not decide anything. Ask your care team."
    static let failedText = "The phone\u{2019}s AI could not explain this. Ask your care team."

    private let explainer: CheckExplainer

    // UI the words once they are ready
    private(set) var text: String?
    private(set) var isWorking = false
    private(set) var failed = false

    // nil uses the phone's own ai
    init(explainer: CheckExplainer? = nil) {
        self.explainer = explainer ?? PhoneCheckExplainer()
    }

    // hidden when the phone's AI is not ready
    var isAvailable: Bool { explainer.isAvailable }

    // one explanation at a time, only when the phone ai is ready
    func explain(_ card: PaperCheckCardData) async {
        guard !isWorking, explainer.isAvailable else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let words = try await explainer.explain(Self.prompt(for: card)).trimmingCharacters(in: .whitespacesAndNewlines)
            text = words.isEmpty ? nil : words
            failed = words.isEmpty
        } catch {
            text = nil
            failed = true
        }
    }

    // only the quotes doctor names dates and the reason, nothing else from the plan
    static func prompt(for card: PaperCheckCardData) -> String {
        let papers = card.quotes.enumerated().map { index, quote in
            "Paper \(index + 1) from \(quote.doctor) (\(quote.dateText)): \u{201C}\(quote.text)\u{201D}"
        }
        return """
            <papers>
            \(papers.joined(separator: "\n"))
            </papers>

            Why the app cannot tell which paper to follow: \(card.finding.reason).
            """
    }
}
