//
//  PaperAbbreviations.swift
//  Remedy
//
//  plain words for the short forms on hospital papers, shown under a quote
//  a fixed list, never a guess
//

import Foundation

// explains short forms on papers like po, prn and bid in plain words
nonisolated enum PaperAbbreviations {

    // short form and its plain words, matched as whole words, case does not matter
    private static let fixed: [(String, String)] = [
        ("PO", "PO means by mouth."),
        ("BID", "BID means twice a day."),
        ("TID", "TID means 3 times a day."),
        ("QID", "QID means 4 times a day."),
        ("QD", "QD means once a day."),
        ("QHS", "QHS means at bedtime."),
        ("HS", "HS means at bedtime."),
        ("PRN", "PRN means only when needed."),
        ("NSAIDs", "NSAIDs are pain pills like Aleve, Advil and Motrin."),
        ("NSAID", "An NSAID is a pain pill like Aleve, Advil or Motrin."),
        ("DVT", "DVT means a blood clot in the leg."),
        ("PT", "PT means physical therapy."),
        ("NPO", "NPO means nothing by mouth."),
    ]

    // one line per short form found, in the order they appear in the quote
    static func explain(_ quote: String) -> String {
        var found: [(Int, String)] = []
        let words = tokens(in: quote)
        for (index, word) in words.enumerated() {
            let upper = word.uppercased()
            if let line = fixed.first(where: { $0.0.uppercased() == upper })?.1 {
                found.append((index, line))
            } else if let hours = everyHours(upper) {
                found.append((index, "\(word) means every \(hours) hours."))
            } else if upper == "POD", index + 1 < words.count, let day = Int(words[index + 1]) {
                found.append((index, "POD \(day) means \(day) days after surgery."))
            }
        }
        var seen = Set<String>()
        return found.map(\.1).filter { seen.insert($0).inserted }.joined(separator: " ")
    }

    // q8h, q6h and q12h
    private static func everyHours(_ upper: String) -> Int? {
        guard upper.hasPrefix("Q"), upper.hasSuffix("H"), upper.count >= 3 else { return nil }
        return Int(upper.dropFirst().dropLast())
    }

    private static func tokens(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}
