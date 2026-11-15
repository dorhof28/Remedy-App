//
//  ReadGaps.swift
//  Remedy
//
//  what the reader could not find on the papers, so the patient can check it
//  plain rules over counts, nothing is guessed
//

import Foundation

// something a plan usually has that this read did not find
nonisolated struct ReadGap: Identifiable, Equatable {
    enum Kind: String { case surgeryDate, medicines, instructions, visit, doctorPhone }

    let kind: Kind
    let title: String
    let detail: String
    let symbol: String

    var id: String { kind.rawValue }
}

// lists what is missing so the patient can add it or scan another page
nonisolated enum ReadGaps {

    // the things missing, most important first
    static func find(hasSurgeryDate: Bool, medicines: Int, instructions: Int, visits: Int,
                     hasPhone: Bool, paper: PaperKind) -> [ReadGap] {
        var gaps: [ReadGap] = []
        if !hasSurgeryDate {
            gaps.append(ReadGap(kind: .surgeryDate, title: "No surgery date",
                                detail: "Tap to set the day of the operation", symbol: "calendar.badge.exclamationmark"))
        }
        if medicines == 0 {
            gaps.append(ReadGap(kind: .medicines, title: "No medicines found",
                                detail: "Tap to read the page and check", symbol: "pills"))
        }
        if instructions == 0 {
            gaps.append(ReadGap(kind: .instructions, title: "No rules or to-dos found",
                                detail: "Tap to read the page and check", symbol: "checklist"))
        }
        if visits == 0 && paper == .afterSurgery {
            gaps.append(ReadGap(kind: .visit, title: "No follow-up visit",
                                detail: "Tap to read the page and check", symbol: "calendar"))
        }
        if !hasPhone {
            gaps.append(ReadGap(kind: .doctorPhone, title: "No phone number for your doctor",
                                detail: "Tap to add one", symbol: "phone.badge.plus"))
        }
        return gaps
    }
}
