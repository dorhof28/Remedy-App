//
//  NewerPaperRule.swift
//  Remedy
//
//  rule 6: when two papers disagree, does the newer one win on its own
//  it wins only when it comes from the surgeon's office or the hospital,
//  or when the two are printed 1 month or more apart
//  a paper with no printed date never wins on its own
//

import Foundation

// rule 6 of the paper check
nonisolated enum NewerPaperRule {

    // who gave the patient the paper, screen 85
    enum Giver: String, CaseIterable {
        case surgeonsOffice
        case hospital
        case anotherDoctor
        case pharmacy

        var title: String {
            switch self {
            case .surgeonsOffice: return "Surgeon\u{2019}s office"
            case .hospital: return "Hospital, when you went home"
            case .anotherDoctor: return "Another doctor"
            case .pharmacy: return "Pharmacy"
            }
        }

        // short words for a paper card, "Surgery team"
        var shortTitle: String {
            switch self {
            case .surgeonsOffice, .hospital: return "Surgery team"
            case .anotherDoctor: return "Another doctor"
            case .pharmacy: return "Pharmacy"
            }
        }

        var isSurgeryTeam: Bool { self == .surgeonsOffice || self == .hospital }
    }

    // what the rule knows about one paper
    struct PaperFacts {
        var giver: Giver
        var printed: Date?
    }

    // why the newer paper wins or why the patient must ask
    enum Reason: Equatable {
        case fromSurgeryTeam     // the newer paper is from the surgeon's office or hospital
        case monthApart          // printed 1 month or more apart
        case noPrintedDate       // one of them has no printed date
        case samePrintedDay      // no way to tell which is newer
        case tooClose            // another giver, less than a month newer
    }

    // the newer paper is followed, or the office has to say
    enum Outcome: Equatable {
        case newerWins(Reason)
        case ask(Reason)

        var newerWins: Bool { if case .newerWins = self { return true } else { return false } }
    }

    // the two papers in any order
    static func decide(_ first: PaperFacts, _ second: PaperFacts, calendar: Calendar = DayMath.calendar) -> Outcome {
        guard let a = first.printed, let b = second.printed else { return .ask(.noPrintedDate) }
        let dayA = calendar.startOfDay(for: a)
        let dayB = calendar.startOfDay(for: b)
        guard dayA != dayB else { return .ask(.samePrintedDay) }
        let (older, newer) = dayA < dayB ? ((first, dayA), (second, dayB)) : ((second, dayB), (first, dayA))
        if newer.0.giver.isSurgeryTeam { return .newerWins(.fromSurgeryTeam) }
        if let month = calendar.date(byAdding: .month, value: 1, to: older.1), newer.1 >= month {
            return .newerWins(.monthApart)
        }
        return .ask(.tooClose)
    }

    // whole days from the older printed date to the newer one, nil without both dates
    static func daysApart(_ first: PaperFacts, _ second: PaperFacts, calendar: Calendar = DayMath.calendar) -> Int? {
        guard let a = first.printed, let b = second.printed else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
        return abs(days)
    }

    // the footnote under both papers on screen 16 and the footer on 48
    static func explanation(_ outcome: Outcome, newerGiver: Giver, daysApart: Int?) -> String {
        switch outcome {
        case .newerWins(.fromSurgeryTeam):
            return "Your newer paper is from your surgery team, so it replaces the older lines. Something not mentioned is never restarted on its own."
        case .newerWins:
            return "Your newer paper is printed a month or more later, so it replaces the older lines. Something not mentioned is never restarted on its own."
        case .ask(.noPrintedDate):
            return "One paper has no printed date, so Remedy can\u{2019}t tell which is right."
        case .ask(.samePrintedDay):
            return "Both papers are printed the same day, so Remedy can\u{2019}t tell which is right."
        case .ask:
            let who = newerGiver == .pharmacy ? "the pharmacy" : "another doctor"
            let days = daysApart.map { $0 == 1 ? "1 day later" : "\($0) days later" } ?? "less than a month later"
            return "The newer paper is from \(who), \(days), so Remedy can\u{2019}t tell which is right."
        }
    }
}
