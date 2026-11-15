//
//  PatientNames.swift
//  Remedy
//
//  names the patient typed in so we can always hide them even with typos
//

import Foundation
import UIKit

// the patient's names, kept in the keychain and hidden from every page before reading
enum PatientNames {

    // saved in the keychain on this phone only
    static let keychainKey = "patientNames"

    static var savedText: String { KeychainStore.read(keychainKey) ?? "" }

    static var saved: [String] { parse(savedText) }

    // an empty list deletes the keychain entry
    static func save(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            KeychainStore.delete(keychainKey)
        } else {
            _ = KeychainStore.save(clean, for: keychainKey)
        }
    }

    // the typed first name added to the saved list once, so it is always hidden
    static func adding(_ name: String, to text: String) -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return text }
        let names = parse(text)
        if names.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) { return text }
        return (names + [clean]).joined(separator: ", ")
    }

    // the name typed in setup joins the saved names
    static func addTypedName(_ name: String) {
        save(adding(name, to: savedText))
    }

    // john smith and mary smith to the two names
    static func parse(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // every word of every name lower case
    static func words(_ names: [String]) -> [String] {
        Array(Set(names.flatMap { $0.lowercased().split { !$0.isLetter && $0 != "'" && $0 != "-" }.map(String.init) }))
            .filter { $0.count >= 2 }
    }

    // hides each word on the page that is a name word or one or two letters off
    // so the camera reading smlth or SMITH still gets hidden
    static func hide(in text: String, names: [String]) -> (String, [String]) {
        let nameWords = words(names)
        guard !nameWords.isEmpty, let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9'\u{2019}-]+") else { return (text, []) }
        var result = text
        var found: [String] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let word = String(text[range])
            if isNameWord(word, nameWords), let target = Range(match.range, in: result) {
                result.replaceSubrange(target, with: Redactor.mark)
                found.append(word)
            }
        }
        return (result, found)
    }

    // does this piece of text hold a name word
    static func contains(_ text: String, names: [String]) -> Bool {
        let nameWords = words(names)
        guard !nameWords.isEmpty else { return false }
        return text.split { !$0.isLetter && $0 != "'" && $0 != "-" }.contains { isNameWord(String($0), nameWords) }
    }

    // MARK: - Private

    // names are printed with a capital so only capitalized words count
    // a typo must start with the same letter and not be a real word like have for hale
    // the camera reads O as 0 and l as 1 so 0rtiz is ortiz
    static func isNameWord(_ word: String, _ nameWords: [String]) -> Bool {
        guard let first = word.first, first.isUppercase || first == "0" || first == "1",
              word.contains(where: \.isLetter) else { return false }
        let lower = String(word.lowercased().map { $0 == "0" ? "o" : $0 == "1" ? "l" : $0 })
        if nameWords.contains(lower) { return true }
        guard lower.count >= 4, !MedicalWords.isProtected(lower), !isRealWord(lower) else { return false }
        return nameWords.contains { name in
            let allowed = name.count >= 7 ? 2 : name.count >= 4 ? 1 : 0
            return name.first == lower.first && abs(name.count - lower.count) <= allowed && distance(name, lower) <= allowed
        }
    }

    private static let checker = UITextChecker()

    // a normal dictionary word is never a camera typo of a name
    private static func isRealWord(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US").location == NSNotFound
    }

    // letters to change to get from one word to the other
    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
