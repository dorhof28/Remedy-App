//
//  NameFinder.swift
//  Remedy
//
//  finds peoples names with apples language tools on the phone
//

import Foundation
import NaturalLanguage

enum NameFinder {

    // words before a name that mean its staff
    private static let staffBefore: Set<String> = [
        "dr", "dr.", "doctor", "surgeon", "physician", "provider", "nurse", "attending", "resident",
        "anesthesiologist", "therapist", "pharmacist", "coordinator", "by",
    ]

    // letters after a name that mean its staff
    private static let staffAfter: Set<String> = [
        "md", "m.d.", "do", "rn", "np", "pa", "pa-c", "aprn", "fnp", "crna", "dpt", "phd", "dds", "lpn", "bsn",
    ]

    // every person name that isnt a doctor or nurse
    static func patientNames(in text: String) -> [String] {
        var names: [String] = []
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            guard tag == .personalName else { return true }
            let name = String(text[range])
            let words = name.split(separator: " ").map(String.init)
            if !name.contains(Redactor.mark), !isStaff(range, in: text), !words.allSatisfy(MedicalWords.isProtected) {
                names.append(name)
            }
            return true
        }
        return names
    }

    // dr before or md after on the same line
    private static func isStaff(_ range: Range<String.Index>, in text: String) -> Bool {
        let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let lineEnd = text[range.upperBound...].firstIndex(of: "\n") ?? text.endIndex
        let before = words(in: text[lineStart..<range.lowerBound])
        let after = words(in: text[range.upperBound..<lineEnd])
        if before.suffix(3).contains("patient") { return false }
        return before.suffix(2).contains { staffBefore.contains($0) } || after.prefix(2).contains { staffAfter.contains($0) }
    }

    private static func words(in text: Substring) -> [String] {
        text.lowercased().split { !$0.isLetter && $0 != "." && $0 != "-" }.map(String.init)
    }
}
