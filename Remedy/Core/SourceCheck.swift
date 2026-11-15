//
//  SourceCheck.swift
//  Remedy
//
//  checks ai answers are really on the page - from nikhil
//

import Foundation

// finds text on the page
nonisolated struct SourceMatcher {

    let text: String
    private let normalized: String
    private let compact: String         // no spaces, so "81mg" matches "81 mg"

    // keeps three forms of the page text so quotes match with or without spaces and case
    init(text: String) {
        self.text = text
        self.normalized = Self.normalize(text)
        self.compact = normalized.replacingOccurrences(of: " ", with: "")
    }

    // is this piece of text on the page
    func contains(_ fragment: String) -> Bool {
        let needle = Self.normalize(fragment)
        return !needle.isEmpty && normalized.contains(needle)
    }

    // same but spaces don't count
    func containsIgnoringSpaces(_ fragment: String) -> Bool {
        let needle = Self.normalize(fragment).replacingOccurrences(of: " ", with: "")
        return !needle.isEmpty && compact.contains(needle)
    }

    // the first line on the page that has this piece of text
    func firstLine(containing fragment: String) -> String? {
        let needle = Self.normalize(fragment)
        guard !needle.isEmpty else { return nil }
        return text.components(separatedBy: .newlines)
            .first { Self.normalize($0).contains(needle) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // lowercase and one space between words
    static func normalize(_ string: String) -> String {
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let scalars = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(scalars).split(separator: " ").joined(separator: " ")
    }
}

// checks numbers and days are written
nonisolated enum SourceCheck {

    // is this day number really written in the text
    static func isDayStated(_ day: Int, in text: String) -> Bool {
        let amount = abs(day)
        if amount <= 1 { return true }
        if isNumberStated(amount, in: text) { return true }
        return amount % 7 == 0 && isNumberStated(amount / 7, in: text)
    }

    // "4" or "four" is in the text
    static func isNumberStated(_ number: Int, in text: String) -> Bool {
        let words = SourceMatcher.normalize(text).split(separator: " ").map(String.init)
        let spelled = number < numberWords.count ? numberWords[number] : nil
        return words.contains { $0 == String(number) || $0 == spelled }
    }

    private static let numberWords = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty",
    ]
}
