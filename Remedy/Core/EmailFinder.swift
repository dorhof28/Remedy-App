//
//  EmailFinder.swift
//  Remedy
//
//  finds an email address on the papers for a contact, plain text rules only
//

import Foundation

// finds email addresses on papers for the contacts list
nonisolated enum EmailFinder {

    // every address in the text, in order, no repeats
    static func addresses(in text: String) -> [String] {
        var found: [String] = []
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:<>()[]\"'"))
        for piece in text.components(separatedBy: separators) {
            // trailing full stops belong to the sentence
            var word = piece
            while word.hasSuffix(".") { word.removeLast() }
            guard isAddress(word), !found.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) else { continue }
            found.append(word)
        }
        return found
    }

    // the address on the same line as the phone number or the contact name, or on the line just after
    static func address(forPhone phone: String, name: String, in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let wanted = phone.filter(\.isNumber)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var matches: [Int] = []
        for (index, line) in lines.enumerated() {
            let hasPhone = wanted.count >= 7 && line.filter(\.isNumber).contains(wanted)
            let hasName = cleanName.count >= 4 && line.lowercased().contains(cleanName)
            if hasPhone { matches.insert(index, at: 0) } else if hasName { matches.append(index) }
        }
        for index in matches {
            for near in [index, index + 1] where near < lines.count {
                if let found = addresses(in: lines[near]).first { return found }
            }
        }
        return nil
    }

    // one @ with text each side and a dot in the domain
    static func isAddress(_ text: String) -> Bool {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !text.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}
