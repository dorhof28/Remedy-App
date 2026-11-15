//
//  PaperClues.swift
//  Remedy
//
//  who gave a paper, the doctor and the printed date from plain rules
//

import Foundation

// what we think a paper is, every part can be unknown
nonisolated struct PaperGuess: Equatable {
    var source: PaperSource?
    var field: PaperField?
    var doctor = ""
    var date: Date?
    var hospital = ""
}

// guesses who gave a paper and its printed date from the words on it
nonisolated enum PaperClues {

    // words in the top or bottom of a letter that name a kind of doctor
    private static let fieldCues: [(field: PaperField, words: [String])] = [
        (.heart, ["cardiology", "heart clinic", "heart doctor"]),
        (.kidney, ["nephrology", "kidney doctor", "kidney clinic"]),
        (.blood, ["hematology", "blood doctor", "blood and clotting"]),
        (.diabetes, ["endocrinology", "diabetes doctor", "diabetes center", "diabetes clinic"]),
        (.lungs, ["pulmonology", "lung doctor", "lung clinic"]),
    ]
    private static let primaryCareCues = ["primary care", "family medicine", "internal medicine", "family doctor"]
    private static let surgeryCues = ["pre-admission", "preadmission", "pre-op", "surgeon", "surgery", "orthopedic", "anesthesia"]

    // a line holding only a doctor's name like the signature
    private static let doctorLine = try? NSRegularExpression(
        pattern: #"^Dr\.?\s+[A-Z][A-Za-z'’-]+(?:\s+[A-Z][A-Za-z'’-]+){0,2}(?:,\s*(?:MD|DO|NP|PA))?$"#)

    // everything the rules can find
    static func guess(from pages: [String]) -> PaperGuess {
        let kind = source(in: pages)
        return PaperGuess(source: kind?.source, field: kind?.field,
                          doctor: doctorName(in: pages), date: printedDate(in: pages),
                          hospital: HospitalFinder.find(in: pages) ?? "")
    }

    // the paper's own date, never the surgery, a visit or a birthday
    static func printedDate(in pages: [String]) -> Date? {
        DateRoles.paperDate(in: pages)
    }

    // the last line that is only Dr. and a name
    static func doctorName(in pages: [String]) -> String {
        guard let regex = doctorLine else { return "" }
        return lines(of: pages).reversed().first {
            regex.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
        } ?? ""
    }

    // who gave it from the letterhead and the signature, nil when no cue
    static func source(in pages: [String]) -> (source: PaperSource, field: PaperField?)? {
        let all = lines(of: pages)
        let text = (all.prefix(6) + all.suffix(5)).joined(separator: "\n").lowercased()
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if let cue = fieldCues.first(where: { has($0.words) }) { return (.specialist, cue.field) }
        if has(primaryCareCues) { return (.primaryCare, nil) }
        if has(surgeryCues) { return (.surgeryTeam, nil) }
        return nil
    }

    // the phone ai's answer kept only where the paper backs it up, the rules fill the rest
    // a date or name the ai made up never gets through
    static func merged(ai: PaperGuess?, rules: PaperGuess, pages: [String]) -> PaperGuess {
        guard let ai else { return rules }
        let text = pages.joined(separator: "\n")
        var result = rules
        if let source = ai.source {
            result.source = source
            result.field = source == .specialist ? ai.field : nil
        }
        if !ai.doctor.isEmpty, text.localizedCaseInsensitiveContains(ai.doctor) { result.doctor = ai.doctor }
        // the ai's date counts only when it is written and is not labelled as the surgery, a visit or a birthday
        if let date = ai.date, writtenDates(in: text).contains(date), !DateRoles.isOtherDay(date, in: pages) {
            result.date = date
        }
        return result
    }

    // every written date on the page
    private static func writtenDates(in text: String) -> [Date] {
        SurgeryDateFinder.dates(in: text).compactMap {
            ExplicitDateParser.parse(date: $0.replacingOccurrences(of: ".", with: ""))
        }
    }

    // every non empty line of every page
    private static func lines(of pages: [String]) -> [String] {
        pages.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Before or after surgery

// what the rules think the papers are, said with the words that gave it away
nonisolated struct PaperKindGuess: Equatable {
    var kind: PaperKind
    var isSure: Bool        // false when the words did not clearly say, kind is then only the usual one
    var clue: String        // the words found, empty when none
}

nonisolated extension PaperClues {

    private static let afterCues = [
        "going home", "after your surgery", "after surgery", "discharge", "post-op", "postop",
        "post-operative", "postoperative", "recovery at home", "caring for your", "wound care",
        "when you get home", "once you are home",
    ]
    private static let beforeCues = [
        "pre-op", "preop", "pre-admission", "preadmission", "pre-surgery", "presurgery",
        "before your surgery", "before surgery", "day before", "night before", "morning of surgery",
        "preparing for", "prepare for", "do not eat or drink", "nothing to eat",
    ]

    // before or after surgery from the words on the papers, the usual kind when nothing is clear
    // a cue in the title lines counts three times, a gap of two or more is needed to be sure
    static func kind(in pages: [String], usual: PaperKind = .beforeSurgery) -> PaperKindGuess {
        let all = lines(of: pages).map { $0.lowercased() }
        let title = all.prefix(4).joined(separator: "\n")
        let body = all.joined(separator: "\n")
        // how many cue words a line has and the first one found
        func score(_ cues: [String]) -> (points: Int, first: String) {
            var points = 0
            var first = ""
            for cue in cues {
                let inBody = body.components(separatedBy: cue).count - 1
                guard inBody > 0 else { continue }
                if first.isEmpty { first = cue }
                points += inBody + (title.contains(cue) ? 2 : 0)
            }
            return (points, first)
        }
        let after = score(afterCues)
        let before = score(beforeCues)
        if after.points - before.points >= 2 { return PaperKindGuess(kind: .afterSurgery, isSure: true, clue: after.first) }
        if before.points - after.points >= 2 { return PaperKindGuess(kind: .beforeSurgery, isSure: true, clue: before.first) }
        return PaperKindGuess(kind: usual, isSure: false, clue: "")
    }

    // each line sorted by its own day, so papers that cover both before and after surgery need no question
    // surgery day and lines with no day keep the kind the page as a whole looks like
    static func kind(forDay day: Int?, fallback: PaperKind) -> PaperKind {
        guard let day, day != 0 else { return fallback }
        return day < 0 ? .beforeSurgery : .afterSurgery
    }

    // true when the page has clear words for both before and after surgery
    static func coversBoth(_ pages: [String]) -> Bool {
        let body = lines(of: pages).joined(separator: "\n").lowercased()
        return afterCues.contains(where: body.contains) && beforeCues.contains(where: body.contains)
    }

    // MyChart and Health do not say which papers they are, so a surgery date in the past means after
    // and one still to come or none means before
    static func kind(importedSurgeryDate: Date?, now: Date, usual: PaperKind = .beforeSurgery) -> PaperKind {
        guard let date = importedSurgeryDate else { return usual }
        let calendar = DayMath.calendar
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: now) ? .afterSurgery : .beforeSurgery
    }
}
