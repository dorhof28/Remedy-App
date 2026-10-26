//
//  TypoFixer.swift
//  Remedy
//
//  fixes obvious misread words on the phone with apples spell checker
//

import Foundation
import UIKit

enum TypoFixer {

    // letters the camera mixes up most
    private static let lookAlikes: [(String, String)] = [
        ("rn", "m"), ("m", "rn"), ("l", "i"), ("i", "l"), ("1", "l"), ("0", "o"), ("5", "s"), ("vv", "w"), ("cl", "d"),
    ]

    // fixes a word only when the checker is sure
    // numbers medicine names and words with capitals in the middle are left alone
    static func fix(_ text: String) -> String {
        let checker = UITextChecker()
        for word in MedicalWords.medicines where !UITextChecker.hasLearnedWord(word) {
            UITextChecker.learnWord(word)
        }
        var result = text
        var offset = 0
        let ns = text as NSString
        let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9]{4,}")
        for match in regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
            let word = ns.substring(with: match.range)
            guard let better = correction(for: word, checker: checker) else { continue }
            let range = NSRange(location: match.range.location + offset, length: match.range.length)
            result = (result as NSString).replacingCharacters(in: range, with: better)
            offset += better.utf16.count - word.utf16.count
        }
        return result
    }

    // one clear fix or nil
    private static func correction(for word: String, checker: UITextChecker) -> String? {
        let digits = word.filter(\.isNumber).count
        guard digits <= 1, !MedicalWords.isProtected(word), !isKnown(word, checker) else { return nil }
        let inner = word.dropFirst()
        guard inner == inner.lowercased() || word == word.uppercased() else { return nil }    // like McKesson

        // look alike letters first since thats what cameras get wrong
        for (wrong, right) in lookAlikes {
            var start = word.startIndex
            while let range = word.range(of: wrong, options: .caseInsensitive, range: start..<word.endIndex) {
                var candidate = word
                candidate.replaceSubrange(range, with: matchCase(right, like: String(word[range])))
                if digitsFree(candidate), isKnown(candidate, checker) { return candidate }
                start = range.upperBound
            }
        }
        // then the checker's own guess only if its the only one
        guard digits == 0, word == word.lowercased() else { return nil }     // capitals could be a name or brand
        let guesses = checker.guesses(forWordRange: NSRange(location: 0, length: word.utf16.count),
                                      in: word, language: "en_US") ?? []
        guard guesses.count == 1, let guess = guesses.first, abs(guess.count - word.count) <= 1 else { return nil }
        return matchCase(guess, like: word)
    }

    private static func isKnown(_ word: String, _ checker: UITextChecker) -> Bool {
        checker.rangeOfMisspelledWord(in: word, range: NSRange(location: 0, length: word.utf16.count),
                                      startingAt: 0, wrap: false, language: "en_US").location == NSNotFound
    }

    private static func digitsFree(_ word: String) -> Bool { !word.contains(where: \.isNumber) }

    private static func matchCase(_ word: String, like original: String) -> String {
        if original == original.uppercased() { return word.uppercased() }
        if original.first?.isUppercase == true { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }
}
