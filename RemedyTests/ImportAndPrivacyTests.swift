//
//  ImportAndPrivacyTests.swift
//  RemedyTests
//
//  what mychart brings in, what the patient picks, and what is hidden before anything leaves the phone
//

import Foundation
import Testing
@testable import Remedy

@Suite struct RecordImportTests {

    private let now = Fixtures.date("2026-11-15 10:00")

    @Test func sampleRecordMapsSurgeryVisitsAndMedicines() {
        let draft = SampleFHIR.draft(paper: .beforeSurgery, now: now)
        #expect(draft.source == .epic)
        #expect(draft.procedure == "Right knee replacement")
        #expect(draft.surgeryDate.map { DayMath.dayOffset(of: $0, from: now) } == 5)
        #expect(draft.appointments.count == 2)
        #expect(draft.medicines.count == 4)
        // the on hold order is a stop, the as needed one is only when needed
        #expect(draft.medicines.contains { $0.name.lowercased().hasPrefix("ibuprofen") && $0.action == .stop })
        #expect(draft.medicines.contains { $0.action == .takeAsNeeded })
    }

    @Test func samplePapersAreReadableHTML() {
        let papers = SampleFHIR.papers(now: now)
        #expect(papers.map(\.title) == ["Pre-op Instructions", "Office Visit Summary"])
        #expect(papers[0].text.contains("Stop ibuprofen 7 days before surgery."))
        #expect(!papers[0].text.contains("<p>"))
        // fake data is marked
        #expect(papers.allSatisfy { $0.text.hasPrefix("SAMPLE") })
    }

    @Test func onlyTextAndHTMLNotesAreRead() {
        typealias Attachment = FHIRDocumentReference.Attachment
        #expect(FHIRMapper.isReadable(Attachment(contentType: "text/plain", url: nil, data: nil, title: nil)))
        #expect(FHIRMapper.isReadable(Attachment(contentType: "text/html; charset=utf-8", url: nil, data: nil, title: nil)))
        #expect(!FHIRMapper.isReadable(Attachment(contentType: "application/pdf", url: nil, data: nil, title: nil)))
        #expect(!FHIRMapper.isReadable(Attachment(contentType: nil, url: nil, data: nil, title: nil)))
    }

    @Test func emptyNoteIsLeftOut() {
        let note = FHIRDocumentReference(resourceType: "DocumentReference", id: "1", status: "current", date: nil,
                                         description: nil, type: nil, content: nil)
        #expect(FHIRMapper.paper(note, text: "  \n ") == nil)
        #expect(FHIRMapper.paper(note, text: "Walk daily")?.title == "Visit paper")
    }

    @Test func rowsListSurgeryVisitsPapersThenMedicines() {
        let draft = SampleFHIR.draft(paper: .beforeSurgery, now: now)
        let rows = ImportPicks.rows(for: draft, papers: SampleFHIR.papers(now: now))
        #expect(rows.map(\.group) == [.visits, .visits, .visits, .papers, .papers, .medicines])
        #expect(rows[0].kind == .surgery)
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test func onlyPickedItemsAreKept() {
        let draft = SampleFHIR.draft(paper: .beforeSurgery, now: now)
        let papers = SampleFHIR.papers(now: now)
        let rows = ImportPicks.rows(for: draft, papers: papers)
        let picked = Set(rows.filter { $0.group == .papers || $0.kind == .medicines }.map(\.id)).subtracting(["paper-sample-2"])
        let kept = ImportPicks.apply(picked: picked, to: draft)
        #expect(kept.surgeryDate == nil)
        #expect(kept.procedure.isEmpty)
        #expect(kept.appointments.isEmpty)
        #expect(kept.medicines.count == 4)
        #expect(ImportPicks.pickedPapers(picked, from: papers).map(\.id) == ["sample-1"])
    }

    @Test func importButtonCountsItems() {
        #expect(ImportPicks.buttonTitle(picked: 0) == "Import")
        #expect(ImportPicks.buttonTitle(picked: 1) == "Import 1 Item")
        #expect(ImportPicks.buttonTitle(picked: 6) == "Import 6 Items")
    }

    @Test func recordItemsAddToPapersAndNeverReplaceThem() {
        var papers = DraftPlan(paper: .beforeSurgery)
        papers.procedure = "Left knee replacement"
        papers.medicines = [DraftMedicine(name: "Aspirin", action: .stop, quote: "Stop aspirin")]
        var record = DraftPlan(paper: .beforeSurgery)
        record.procedure = "Knee arthroplasty"
        record.surgeryDate = now
        record.hospitalName = "Lakeside Health"
        record.medicines = [DraftMedicine(name: "aspirin", action: .take, quote: ""),
                            DraftMedicine(name: "Metformin", action: .take, quote: "")]
        let merged = papers.addingRecord(record)
        #expect(merged.procedure == "Left knee replacement")
        #expect(merged.surgeryDate == now)
        #expect(merged.hospitalName == "Lakeside Health")
        // the paper's aspirin stays a stop, the record only adds what the papers do not name
        #expect(merged.medicines.map(\.name) == ["Aspirin", "Metformin"])
        #expect(merged.medicines[0].action == .stop)
    }
}

@Suite(.serialized) struct PrivacyTests {

    @Test func typedNamesAreHiddenEverywhere() {
        let page = "Patient: Avery Quinn\nAvery should stop aspirin. Call Dr. Lee at 201-555-0142."
        let redacted = Redactor.redact(page, names: ["Avery Quinn"])
        #expect(!redacted.text.contains("Avery"))
        #expect(!redacted.text.contains("Quinn"))
        // medicine words are never hidden
        #expect(redacted.text.contains("aspirin"))
        #expect(redacted.removedCount > 0)
    }

    @Test func idNumbersOnTheHeaderAreHidden() {
        let page = "MRN 4400187  DOB 03/14/1961\nStop ibuprofen 7 days before surgery."
        let redacted = Redactor.redact(page, names: [])
        #expect(!redacted.text.contains("4400187"))
        #expect(!redacted.text.contains("03/14/1961"))
        #expect(redacted.text.contains("Stop ibuprofen 7 days before surgery."))
    }

    @Test func tappingShowsAndHidesEveryCopy() {
        var page = Redactor.redact("Avery took aspirin. Avery feels fine.", names: ["Avery"])
        #expect(page.hidden == ["Avery"])
        page.show("Avery")
        #expect(page.removedCount == 0)
        page.hide("aspirin")
        #expect(!page.text.contains("aspirin"))
    }

    @Test func patientNameWordsAreSplit() {
        #expect(PatientNames.parse("Avery Quinn, Sam").contains("Avery Quinn"))
        let (hidden, found) = PatientNames.hide(in: "Avery Quinn signed", names: ["Avery Quinn"])
        #expect(!hidden.contains("Avery"))
        #expect(!found.isEmpty)
    }
}
