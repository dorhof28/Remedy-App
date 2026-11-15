//
//  LeftOutItem.swift
//  Remedy
//
//  something the AI said that was not on the papers, so it was left out
//  plain data so the patient can see each one
//

import Foundation

// an item the ai answered that the converter did not keep, with why
nonisolated struct LeftOutItem: Identifiable, Equatable {
    enum Kind: String { case medicine, rule, task, visit }

    let id: Int
    let kind: Kind
    let name: String
    let aiSaid: String      // the words the AI gave
    let reason: String
    let quote: String       // the quote the AI gave, may be empty
    let page: Int?          // only when the quote is on a page

    static let notOnPapers = "Not found on your papers"
    static let noName = "The AI gave no name for it"

}

// the words for the left out items row and sheet
nonisolated enum LeftOutItems {
    // the start of the warning the converter adds, so the screen can show a tappable row instead
    static let warningStart = "We left out "

    static func isLeftOutWarning(_ text: String) -> Bool { text.hasPrefix(warningStart) }

    // "We left out 1 item"
    static func title(count: Int) -> String {
        "We left out \(PlainText.count(count, "item"))"
    }

    // an empty name falls back to the first words the AI gave
    static func displayName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let other = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return other.isEmpty ? "Unnamed item" : other
    }
}
