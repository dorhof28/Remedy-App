//
//  ScanFlowTypes.swift
//  Remedy
//
//  the small types of the scan flow
//

import Foundation

// where we are in the flow
enum ScanStep: Equatable {
    case welcome
    case addPapers          // where are the papers, also where a failed read lands
    case pages              // the scanned pages, checked before anything is read
    case importPick         // what mychart or health found, picked before the check
    case paperDetails       // confirm who gave it, the doctor and the printed date
    case reading
    case checkHidden        // the patient checks the hidden page before it leaves the phone
    case confirm
    case finish
    case whatChanged        // after a new paper joins a plan
    case setup              // lock calendar and reminders, once, before the first plan is saved
}

// the real steps "reading" goes through shown as a checklist
enum ReadingStage: Int, CaseIterable, Identifiable {
    case readingWords
    case removingPersonalInfo
    case modelReading
    case findingInstructions
    case done

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .readingWords: return "text.viewfinder"
        case .removingPersonalInfo: return "eye.slash"
        case .modelReading: return "sparkles"
        case .findingInstructions: return "list.bullet.clipboard"
        case .done: return "checkmark.seal.fill"
        }
    }
}

// which kind of item a card is and where it sits in the draft
enum ConfirmItem: Equatable {
    case medicine(Int)
    case rule(Int)
    case task(Int)
    case appointment(Int)
}

// one card on the Confirm screen
struct ConfirmCard: Identifiable {
    let id: UUID
    let item: ConfirmItem
    let eyebrow: String         // "Stop taking"
    let symbol: String
    let tone: Tone
    let title: String           // "Ibuprofen (Motrin, Advil)"
    var subtitle: String = ""   // "500 mg tablet"
    var text: String = ""       // "Don't take it until your surgeon says it's OK."
    let facts: [InfoRow]        // How much / When / For / Until ...
    let quote: String
    let quoteSource: String
    var plainWords: String = "" // "PO means by mouth."
}

// what the Edit sheet can change
struct ConfirmEdit {
    var title: String
    var hasStart: Bool
    var startDay: Int
    var hasEnd: Bool
    var endDay: Int
    var showsDays: Bool         // visits use their date instead
}

// the questions of "About this paper", the doctor is read from the paper and never asked
// kind only comes up when the rules sorted the papers or disagree with the patient
enum PaperDetailsStep: Int, CaseIterable {
    case kind, who, date
}

// what the patient said about before or after surgery
enum PaperChoice: Equatable {
    case before, after, notSure
}

// where the papers come from, picked before before or after surgery
enum PaperIntake: String, CaseIterable, Identifiable {
    case camera, photos, pdf, myChart, health
    case sample     // debug and demo only

    var id: String { rawValue }
}

extension String {
    // without spaces and new lines at the ends
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension DraftTask {
    // a to-do Remedy adds itself, already confirmed
    static func confirmedTodo(_ title: String) -> DraftTask {
        DraftTask(title: title, dueDay: nil, quote: "", isConfirmed: true)
    }
}
