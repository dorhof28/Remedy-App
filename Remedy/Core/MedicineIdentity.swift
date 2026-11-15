//
//  MedicineIdentity.swift
//  Remedy
//
//  says when two lines are about the same medicine, exact names only
//

import Foundation

// decides when two names are the same medicine, brand or generic
nonisolated enum MedicineIdentity {

    // generic name first then brands, already normalized
    static let brands: [[String]] = [
        ["aspirin"],
        ["clopidogrel", "plavix"],
        ["apixaban", "eliquis"],
        ["warfarin", "coumadin"],
        ["ibuprofen", "advil", "motrin"],
        ["naproxen", "aleve"],
        ["metformin"],
        ["metoprolol"],
        ["lisinopril"],
        ["atorvastatin", "lipitor"],
        ["omeprazole", "prilosec"],
        ["acetaminophen", "tylenol"],
        ["oxycodone"],
        ["fish oil", "omega 3"],
    ]

    // a kind of medicine a paper names as a whole
    struct Group {
        let names: [String]
        let members: [String]
    }

    // aspirin is not an nsaid here, pre-op papers name it on its own
    static let groups: [Group] = [
        Group(names: ["nsaids", "nsaid"], members: ["ibuprofen", "naproxen", "celecoxib", "diclofenac", "meloxicam"]),
        Group(names: ["blood thinners", "blood thinner"], members: ["aspirin", "clopidogrel", "warfarin", "apixaban", "rivaroxaban"]),
        Group(names: ["vitamins and supplements", "vitamins", "supplements"], members: ["fish oil", "multivitamin", "vitamin e"]),
    ]

    // lowercase no punctuation no strength
    static func normalized(_ text: String) -> String {
        let noStrength = text.replacingOccurrences(of: MedicineNameCleaner.strengthPattern, with: " ", options: .regularExpression)
        let letters = noStrength.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }

    // own name first then other names and brands from the table
    static func names(_ name: String, alsoKnownAs: [String]) -> [String] {
        var all: [String] = []
        for raw in [name] + alsoKnownAs {
            let clean = normalized(raw)
            if !clean.isEmpty && !all.contains(clean) { all.append(clean) }
        }
        for row in brands where !Set(row).isDisjoint(with: all) {
            all += row.filter { !all.contains($0) }
        }
        return all
    }

    // any shared name means the same medicine
    static func same(_ first: [String], _ second: [String]) -> Bool {
        !Set(first).isDisjoint(with: second)
    }

    // stable name for a medicine both lists share
    static func key(_ first: [String], _ second: [String]) -> String {
        let shared = Set(first).intersection(second)
        return brands.first { !shared.isDisjoint(with: $0) }?.first ?? shared.sorted().first ?? ""
    }

    // members when the names are a group, nil when not a group
    static func groupMembers(of names: [String]) -> [String]? {
        groups.first { !Set($0.names).isDisjoint(with: names) }?.members
    }

    // a group line or 3 or more medicines in one sentence
    static func isGeneric(quote: String, isGroup: Bool, knownNames: [[String]]) -> Bool {
        isGeneric(quote: quote, isGroup: isGroup, phrases: genericPhrases(knownNames: knownNames))
    }

    // every medicine name as a phrase with the medicine it means, longest first so metoprolol succinate counts once
    static func genericPhrases(knownNames: [[String]]) -> [(phrase: String, medicine: String)] {
        let rows = brands + groups.flatMap { $0.members.map { [$0] } } + knownNames
        var phrases: [(phrase: String, medicine: String)] = []
        for row in rows {
            let medicine = key(row, row)
            phrases += row.map { (phrase: $0, medicine: medicine) }
        }
        return phrases.sorted { $0.phrase.count > $1.phrase.count }
    }

    // true when the paper names a group like any nsaid rather than one medicine
    static func isGeneric(quote: String, isGroup: Bool, phrases: [(phrase: String, medicine: String)]) -> Bool {
        if isGroup { return true }
        for sentence in quote.components(separatedBy: CharacterSet(charactersIn: ".!?;\n")) {
            var text = " " + normalized(sentence) + " "
            var found = Set<String>()
            for (phrase, medicine) in phrases where text.contains(" \(phrase) ") {
                found.insert(medicine)
                text = text.replacingOccurrences(of: " \(phrase) ", with: " | ")
            }
            if found.count >= 3 { return true }
        }
        return false
    }
}
