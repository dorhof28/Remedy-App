//
//  ImportPicks.swift
//  Remedy
//
//  what a mychart or health import found, as rows the patient picks before the check
//

import Foundation

// a visit note from the record, read like a scanned page once picked
struct RecordPaper: Identifiable, Equatable {
    let id: String
    let title: String
    let date: Date?
    let text: String
}

// what an import found: the record items and any visit papers
struct RecordImport {
    var draft: DraftPlan
    var papers: [RecordPaper] = []
}

// one thing the import can bring in
struct ImportRow: Identifiable, Equatable {
    // the section a row is listed in
    enum Group: Equatable { case visits, papers, medicines }
    // what the row brings in when ticked
    enum Kind: Equatable { case surgery, visit(UUID), paper(String), medicines }

    let kind: Kind
    let group: Group
    let title: String
    let date: Date?
    let count: Int          // medicines in the list, 1 for a visit

    var id: String {
        switch kind {
        case .surgery: return "surgery"
        case .visit(let id): return "visit-\(id.uuidString)"
        case .paper(let id): return "paper-\(id)"
        case .medicines: return "medicines"
        }
    }
}

// builds the rows and keeps only what the patient ticked
enum ImportPicks {

    // the surgery first, then visits by date, then visit papers newest first, then the medicine list
    static func rows(for draft: DraftPlan, papers: [RecordPaper] = []) -> [ImportRow] {
        var rows: [ImportRow] = []
        if let day = draft.surgeryDate {
            let name = draft.procedure.isEmpty ? "Your surgery" : draft.procedure
            rows.append(ImportRow(kind: .surgery, group: .visits, title: name, date: day, count: 1))
        }
        for visit in draft.appointments.sorted(by: { $0.date < $1.date }) {
            rows.append(ImportRow(kind: .visit(visit.id), group: .visits, title: visit.title, date: visit.date, count: 1))
        }
        for paper in papers {
            rows.append(ImportRow(kind: .paper(paper.id), group: .papers, title: paper.title, date: paper.date, count: 1))
        }
        if !draft.medicines.isEmpty {
            rows.append(ImportRow(kind: .medicines, group: .medicines, title: "Current Medicines",
                                  date: nil, count: draft.medicines.count))
        }
        return rows
    }

    // only what was picked goes on to the check, nothing is added
    static func apply(picked: Set<String>, to draft: DraftPlan) -> DraftPlan {
        var kept = draft
        if !picked.contains("surgery") {
            kept.surgeryDate = nil
            kept.procedure = ""
        }
        kept.appointments = draft.appointments.filter { picked.contains("visit-\($0.id.uuidString)") }
        if !picked.contains("medicines") { kept.medicines = [] }
        return kept
    }

    // the picked papers in the order shown
    static func pickedPapers(_ picked: Set<String>, from papers: [RecordPaper]) -> [RecordPaper] {
        papers.filter { picked.contains("paper-\($0.id)") }
    }

    // the button counts rows, a medicine list is one item
    static func buttonTitle(picked: Int) -> String {
        switch picked {
        case 0: return "Import"
        case 1: return "Import 1 Item"
        default: return "Import \(picked) Items"
        }
    }

    // the subtitle under a medicine list
    static func medicinesText(count: Int) -> String {
        count == 1 ? "1 medicine" : "\(count) medicines"
    }
}
