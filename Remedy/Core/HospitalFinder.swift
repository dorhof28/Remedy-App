//
//  HospitalFinder.swift
//  Remedy
//
//  names the hospital from the letterhead and logo words at the top or bottom of a paper
//  known short forms like HSS first, then any line that ends in hospital, medical center and so on
//

import Foundation

// finds the hospital name on a paper from its short forms and logo words
nonisolated enum HospitalFinder {

    // short forms and names a logo often shows, with the full name
    static let known: [(clues: [String], name: String)] = [
        (["hss", "hospital for special surgery"], "Hospital for Special Surgery"),
        (["nyu langone"], "NYU Langone Health"),
        (["mount sinai", "mt. sinai", "mt sinai"], "Mount Sinai"),
        (["newyork-presbyterian", "new york-presbyterian", "new york presbyterian", "nyp"], "NewYork-Presbyterian"),
        (["memorial sloan kettering", "mskcc", "msk"], "Memorial Sloan Kettering"),
        (["northwell"], "Northwell Health"),
        (["mayo clinic"], "Mayo Clinic"),
        (["cleveland clinic"], "Cleveland Clinic"),
        (["johns hopkins"], "Johns Hopkins"),
        (["massachusetts general", "mass general", "mgh"], "Massachusetts General Hospital"),
        (["brigham and women", "brigham & women"], "Brigham and Women\u{2019}s Hospital"),
        (["cedars-sinai", "cedars sinai"], "Cedars-Sinai"),
        (["kaiser permanente"], "Kaiser Permanente"),
        (["ucsf"], "UCSF Health"),
        (["ucla health"], "UCLA Health"),
        (["stanford health"], "Stanford Health Care"),
        (["penn medicine"], "Penn Medicine"),
        (["montefiore"], "Montefiore"),
    ]

    // words that end a hospital name on a letterhead
    private static let endings = ["hospital", "medical center", "medical centre", "health system", "health",
                                  "clinic", "surgery center", "surgical center", "medical group", "infirmary"]

    // the hospital name or nil, only the top and bottom lines are looked at since that is where the logo is
    static func find(in pages: [String]) -> String? {
        for page in pages {
            let lines = page.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let edge = Array(lines.prefix(6)) + Array(lines.suffix(4))
            for line in edge {
                let words = " " + line.lowercased().map { $0.isLetter || $0 == "-" || $0 == "&" || $0 == "." ? $0 : " " }
                    .reduce(into: "") { $0.append($1) } + " "
                if let hit = known.first(where: { $0.clues.contains { words.contains(" \($0) ") } }) { return hit.name }
            }
            for line in edge where looksLikeName(line) { return line }
        }
        return nil
    }

    // a short title-like line ending in hospital or medical center, never a sentence
    private static func looksLikeName(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard line.count <= 48, !line.contains(":"), endings.contains(where: { lower.hasSuffix($0) }) else { return false }
        let words = line.split(separator: " ")
        guard (2...7).contains(words.count) else { return false }
        // most words start with a capital like a name
        let capitals = words.filter { $0.first?.isUppercase == true }.count
        return capitals * 2 >= words.count + 1
    }
}
