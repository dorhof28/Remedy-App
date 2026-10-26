//
//  MedicineNameCleaner.swift
//  Remedy
//
//  splits a name like baby aspirin 81 mg tablet into name strength and other names
//

import Foundation

// the pieces of a medicine name
struct CleanMedicineName {
    var name: String
    var strength: String
    var otherNames: [String]
}

enum MedicineNameCleaner {

    static let strengthPattern = "(?i)\\b\\d+(?:\\.\\d+)?(?:\\s*[-/]\\s*\\d+(?:\\.\\d+)?)?\\s*(?:mg|mcg|\u{00B5}g|g|ml|units?|iu|meq|%)(?![A-Za-z])"

    // pill shape words that aren't part of the name
    static let formWords: Set<String> = [
        "tablet", "tablets", "tab", "tabs", "capsule", "capsules", "cap", "caps", "pill", "pills", "oral", "po",
        "solution", "liquid", "suspension", "chewable", "by", "mouth",
    ]

    // nicknames that go to other names
    static let nicknameStarts = ["baby ", "low dose ", "low-dose ", "children's ", "childrens "]

    static func clean(_ raw: String) -> CleanMedicineName {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var otherNames: [String] = []
        var strength = ""

        // brand in brackets like oxycodone (roxicodone)
        while let open = name.firstIndex(of: "("), let close = name[open...].firstIndex(of: ")") {
            let inside = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            if inside.contains(where: \.isNumber) {
                if strength.isEmpty, let found = firstStrength(in: inside) { strength = found }
            } else {
                otherNames += inside.components(separatedBy: CharacterSet(charactersIn: ",/")).map {
                    $0.trimmingCharacters(in: .whitespaces).lowercased()
                }
            }
            name.removeSubrange(open...close)
        }

        // strength like 81 mg or 5-325 mg
        if strength.isEmpty, let found = firstStrength(in: name) { strength = found }
        name = name.replacingOccurrences(of: strengthPattern, with: " ", options: .regularExpression)

        // tablet capsule and so on
        name = name.split(separator: " ")
            .filter { !formWords.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))

        // baby aspirin is aspirin with a nickname
        if let start = nicknameStarts.first(where: { name.lowercased().hasPrefix($0) }) {
            otherNames.insert(name.lowercased(), at: 0)
            name = String(name.dropFirst(start.count))
        }

        if name == name.lowercased() { name = name.prefix(1).uppercased() + name.dropFirst() }
        return CleanMedicineName(name: name.isEmpty ? raw : name, strength: strength,
                                 otherNames: otherNames.filter { !$0.isEmpty })
    }

    private static func firstStrength(in text: String) -> String? {
        text.range(of: strengthPattern, options: .regularExpression).map { String(text[$0]).trimmingCharacters(in: .whitespaces) }
    }
}
