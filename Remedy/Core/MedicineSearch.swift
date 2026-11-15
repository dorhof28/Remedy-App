//
//  MedicineSearch.swift
//  Remedy
//
//  what a typed word can find: names, brands, the medicines a group line covers, and plain words like pain
//

import Foundation

// finds medicines from plain words a patient types, like pain or blood thinner
nonisolated enum MedicineSearch {

    // a plain word a patient types and the medicines it means
    struct Topic: Equatable {
        let words: [String]
        let header: String          // "For pain, your plan has"
        let members: [String]
    }

    static let topics: [Topic] = [
        Topic(words: ["pain", "pain pill", "pain pills", "painkiller", "pain killer", "pain medicine"],
              header: "For pain, your plan has",
              members: ["acetaminophen", "oxycodone", "hydrocodone", "tramadol", "ibuprofen", "naproxen",
                        "celecoxib", "diclofenac", "meloxicam"]),
        Topic(words: ["blood thinner", "blood thinners"],
              header: "Blood thinners on your papers",
              members: ["aspirin", "clopidogrel", "warfarin", "apixaban", "rivaroxaban"]),
        Topic(words: ["vitamin", "vitamins", "supplement", "supplements"],
              header: "Vitamins and supplements on your papers",
              members: ["fish oil", "multivitamin", "vitamin e"]),
    ]

    // the word typed, tidy
    static func clean(_ query: String) -> String {
        MedicineIdentity.normalized(query)
    }

    // "pain" or "blood thin" finds its topic, two letters is too few
    static func topic(for query: String) -> Topic? {
        let typed = clean(query)
        guard typed.count >= 3 else { return nil }
        return topics.first { topic in topic.words.contains { $0 == typed || $0.hasPrefix(typed) } }
    }

    // every name one line answers to: its own, brands, and for a group line each member and their brands
    static func names(name: String, alsoKnownAs: [String], isGroup: Bool) -> [String] {
        var all = MedicineIdentity.names(name, alsoKnownAs: alsoKnownAs)
        // "any other nsaid" still names the nsaid group
        let group = MedicineIdentity.groups.first { group in
            group.names.contains { groupName in all.contains { $0 == groupName || " \($0) ".contains(" \(groupName) ") } }
        }
        if let members = group?.members {
            for member in members {
                for extra in MedicineIdentity.names(member, alsoKnownAs: []) where !all.contains(extra) { all.append(extra) }
            }
        }
        return all
    }

    // a line about a whole kind of medicine, "NSAIDs" or "any other nsaid"
    static func isGroupLine(name: String, isGroup: Bool) -> Bool {
        if isGroup { return true }
        let words = " \(MedicineIdentity.normalized(name)) "
        return MedicineIdentity.groups.contains { group in group.names.contains { words.contains(" \($0) ") } }
    }

    // the name that matched, or nil, the start of a name or three letters inside it
    static func match(_ query: String, names: [String]) -> String? {
        let typed = clean(query)
        guard typed.count >= 2 else { return nil }
        return names.first { $0.hasPrefix(typed) || (typed.count >= 3 && $0.contains(typed)) || $0 == typed }
    }

    // a member of a topic, by any of its names
    static func isMember(_ names: [String], of topic: Topic) -> Bool {
        !Set(names).isDisjoint(with: topic.members.flatMap { MedicineIdentity.names($0, alsoKnownAs: []) })
    }

    // "Advil, Motrin and Aleve are the same kind of pain pill (NSAIDs). Your paper, page 3, says to stop them."
    // only nsaids get the sentence, the other groups are not one kind of pill
    static func kindSentence(for query: String, page: Int?) -> String? {
        let typed = clean(query)
        guard typed.count >= 3,
              let nsaids = MedicineIdentity.groups.first(where: { $0.names.contains("nsaids") }) else { return nil }
        let brands = nsaids.members.flatMap { member in MedicineIdentity.names(member, alsoKnownAs: []).dropFirst() }
        let every = nsaids.names + nsaids.members + brands
        guard every.contains(where: { $0.hasPrefix(typed) }) else { return nil }
        let list = PlainText.list(brands.map { $0.capitalized })
        let paper = page.map { "Your paper, page \($0), says" } ?? "Your paper says"
        return "\(list) are the same kind of pain pill (NSAIDs). \(paper) to stop them."
    }
}
