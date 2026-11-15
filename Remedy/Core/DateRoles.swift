//
//  DateRoles.swift
//  Remedy
//
//  says what each written date on a paper is for, from the words around it
//  so the paper date is never an appointment, the surgery or a birthday
//

import Foundation

// what a date on a paper is for
nonisolated enum DateRole: Equatable, Sendable {
    case printed, surgery, appointment, birth, unknown
}

// tells a printed date from a surgery, visit or birth date by the words near it
nonisolated enum DateRoles {

    // one date found on a page, its role and the line it is on
    struct Found: Equatable, Sendable {
        let date: Date
        let role: DateRole
        let lineIndex: Int
    }

    // the label closest before the date wins
    private static let cues: [(role: DateRole, words: [String])] = [
        (.birth, ["dob", "d.o.b", "birth", "born"]),
        (.printed, ["printed", "print date", "date printed", "generated", "created on", "date of service",
                    "visit date", "encounter date", "date of visit", "letter date", "revised", "updated on", "rev."]),
        (.surgery, ["surgery", "procedure", "operation", "operative date"]),
        (.appointment, ["appointment", "appt", "follow-up", "follow up", "followup", "arrive", "arrival", "check-in",
                        "check in", "report to", "come in", "pre-op", "preop", "pre-admission", "testing", "lab work", "labs",
                        "visit with", "see dr", "see you", "return", "clinic on", "post-op"]),
    ]

    // every written date with what it is for
    static func all(in pages: [String]) -> [Found] {
        let lines = pages.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var found: [Found] = []
        for (index, line) in lines.enumerated() {
            for written in SurgeryDateFinder.dates(in: line) {
                guard let date = ExplicitDateParser.parse(date: written.replacingOccurrences(of: ".", with: "")) else { continue }
                // a table label sits on the line above
                let before = String(line[..<(line.range(of: written)?.lowerBound ?? line.endIndex)])
                let above = index > 0 ? lines[index - 1] : ""
                var kind = role(of: before)
                if kind == .unknown, before.trimmingCharacters(in: .whitespaces).count < 3 { kind = role(of: above) }
                if kind == .unknown { kind = role(of: line) }
                found.append(Found(date: date, role: kind, lineIndex: index))
            }
        }
        return found
    }

    // the role whose cue word is nearest the date wins
    static func role(of text: String) -> DateRole {
        let lower = text.lowercased()
        var best: (role: DateRole, at: String.Index)?
        for cue in cues {
            for word in cue.words {
                guard let found = lower.range(of: word, options: .backwards) else { continue }
                if best == nil || found.lowerBound > best!.at { best = (cue.role, found.lowerBound) }
            }
        }
        return best?.role ?? .unknown
    }

    // the paper's own date: a printed label first, then a date standing alone near the top like a letter
    static func paperDate(in pages: [String]) -> Date? {
        let found = all(in: pages)
        if let printed = found.first(where: { $0.role == .printed }) { return printed.date }
        return found.first { $0.role == .unknown && $0.lineIndex < 8 }?.date
    }

    // true when a date only shows up as something other than the paper date
    static func isOtherDay(_ date: Date, in pages: [String]) -> Bool {
        let same = all(in: pages).filter { DayMath.calendar.isDate($0.date, inSameDayAs: date) }
        return !same.isEmpty && same.allSatisfy { [.surgery, .appointment, .birth].contains($0.role) }
    }
}
