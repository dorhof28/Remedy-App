//
//  PaperCheckInput.swift
//  Remedy
//
//  turns a plan's medicines papers and notes into paper check input
//

import Foundation
import SwiftData

// every medicine line from every paper as check items
struct PaperCheckInput {
    // CheckItem.id is the index here
    let medicines: [MedicineInstruction]
    let items: [CheckItem]
    // finding key to the paper the office chose
    let notes: [String: UUID]

    init(plan: CarePlan) {
        let papers = Dictionary(plan.papers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // lines without a paper are from plans made before papers, nothing to compare
        let lines = plan.medicines.filter { $0.paperID.flatMap { papers[$0] } != nil }
        medicines = lines

        let names = lines.map { MedicineIdentity.names($0.name, alsoKnownAs: $0.alsoKnownAs) }
        let members = names.map(MedicineIdentity.groupMembers(of:))
        let isGroup = lines.indices.map { lines[$0].isGroup || members[$0] != nil }
        let known = names.indices.filter { !isGroup[$0] }.map { names[$0] }
        // the name list is built and sorted once for the whole plan, not once per line
        let phrases = MedicineIdentity.genericPhrases(knownNames: known)

        var items: [CheckItem] = []
        for (index, medicine) in lines.enumerated() {
            guard let paperID = medicine.paperID, let paper = papers[paperID] else { continue }
            items.append(CheckItem(
                id: index, paperID: paperID, source: paper.source, field: paper.field,
                printedDate: paper.printedDate, addedAt: paper.addedAt, paperKind: paper.kind, doctorName: paper.doctorName,
                name: medicine.name, names: names[index], isGroup: isGroup[index], groupMembers: members[index] ?? [],
                isGeneric: MedicineIdentity.isGeneric(quote: medicine.quote, isGroup: isGroup[index], phrases: phrases),
                action: medicine.action, startDay: medicine.startDay, endDay: medicine.endDay,
                strength: medicine.strength, amount: medicine.amount, quote: medicine.quote))
        }
        self.items = items

        // the newest note for a finding wins, a failed fetch leaves findings red
        let saved = (try? plan.modelContext?.fetch(FetchDescriptor<PaperCheckNote>(sortBy: [SortDescriptor(\.date)]))) ?? []
        var notes: [String: UUID] = [:]
        for note in saved {
            if let chosen = note.chosenPaperID { notes[note.findingKey] = chosen }
        }
        self.notes = notes
    }

    // everything the check reads, hashed, so an unchanged plan is spotted without redoing the check
    static func fingerprint(of plan: CarePlan) -> Int {
        var hasher = Hasher()
        for paper in plan.papers {
            hasher.combine(paper.id)
            hasher.combine(paper.sourceRaw)
            hasher.combine(paper.fieldRaw)
            hasher.combine(paper.printedDate)
            hasher.combine(paper.addedAt)
            hasher.combine(paper.kindRaw)
            hasher.combine(paper.doctorName)
            hasher.combine(paper.otherKindText)
        }
        for medicine in plan.medicines {
            hasher.combine(medicine.persistentModelID)
            hasher.combine(medicine.paperID)
            hasher.combine(medicine.name)
            hasher.combine(medicine.alsoKnownAs)
            hasher.combine(medicine.isGroup)
            hasher.combine(medicine.actionRaw)
            hasher.combine(medicine.startDay)
            hasher.combine(medicine.endDay)
            hasher.combine(medicine.strength)
            hasher.combine(medicine.amount)
            hasher.combine(medicine.quote)
        }
        let saved = (try? plan.modelContext?.fetch(FetchDescriptor<PaperCheckNote>())) ?? []
        for note in saved.sorted(by: { $0.date < $1.date }) {
            hasher.combine(note.findingKey)
            hasher.combine(note.chosenPaperID)
            hasher.combine(note.date)
        }
        return hasher.finalize()
    }

    var result: PaperCheckResult { PaperCheck.run(items, notes: notes) }
}
