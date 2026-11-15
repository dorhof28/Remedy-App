//
//  ScanFlowViewModel+Import.swift
//  Remedy
//
//  mychart and apple health imports, picked before the check
//

import AuthenticationServices
import Foundation
import SwiftUI

extension ScanFlowViewModel {

    // MARK: - MyChart (Epic)

    // shows once Services/Epic/EpicConfig has a client ID
    var showsEpicButton: Bool { EpicConfig.isSetUp }

    // mychart import then the confirm screen
    func importFromEpic(using webAuth: WebAuthenticationSession) async {
        errorText = nil
        isImportingFromEpic = true
        defer { isImportingFromEpic = false }
        do {
            let found = try await EpicImporter.importPlan(paper: paper, using: webAuth)
            offerImport(found.draft, papers: found.papers, from: .myChart)
        } catch EpicError.cancelled {
            // the patient closed the sign-in just stay here
        } catch {
            failImport((error as? EpicError)?.errorDescription
                ?? "We couldn\u{2019}t reach your hospital. Check your internet, or scan your papers instead.")
        }
    }

    // MARK: - Apple Health Records

    // only on iPhones that can hold Health Records
    var showsHealthButton: Bool { HealthService.canReadRecords }

    // apple health import then the confirm screen
    func importFromHealth() async {
        errorText = nil
        isImportingFromHealth = true
        defer { isImportingFromHealth = false }
        do {
            offerImport(try await HealthRecordsImporter.importPlan(paper: paper), from: .health)
        } catch {
            failImport((error as? HealthImportError)?.errorDescription
                ?? "We couldn\u{2019}t read your Health Records. You can scan your papers instead.")
        }
    }

    // says what went wrong and goes back to where the papers come from
    private func failImport(_ message: String) {
        errorText = message
        Motion.run { step = .addPapers }
    }

    // MARK: - Choose what to import

    // where the imported record came from
    enum ImportSource { case myChart, health }

    var importTitle: String { importSource == .myChart ? "MyChart" : "Apple Health" }
    var importDetail: String {
        switch importSource {
        case .myChart:
            let place = draft?.hospitalName.isEmpty == false ? draft!.hospitalName : "MyChart"
            return "Signed in to \(place). Pick the papers from your surgery."
        case .health:
            return "Pick what to bring in from your Health records."
        }
    }
    var importVisitsHeader: String { "Visits and surgery" }
    var importPapersHeader: String { "Visit papers" }
    var importMedicinesHeader: String { "Medicine list" }
    // papers are read like a scan so they pass the same privacy check
    var importFooter: String {
        importPapers.isEmpty
            ? "Imported items still go through the check, item by item."
            : "Imported papers still go through \u{201C}What the AI will see\u{201D} and the check, item by item."
    }
    var importButton: String { ImportPicks.buttonTitle(picked: pickedImports.count) }
    var canImport: Bool { !pickedImports.isEmpty }

    var importVisitRows: [ImportRow] { importRows.filter { $0.group == .visits } }
    var importPaperRows: [ImportRow] { importRows.filter { $0.group == .papers } }
    var importMedicineRows: [ImportRow] { importRows.filter { $0.group == .medicines } }

    // "Tue, Nov 10 · surgery" or "7 medicines"
    func importSubtitle(_ row: ImportRow) -> String {
        switch row.kind {
        case .medicines: return ImportPicks.medicinesText(count: row.count)
        case .surgery:
            // "Mon, Nov 9 · Lakeside General", or "surgery" when the hospital isn't known
            let place = draft?.hospitalName ?? ""
            return [row.date.map(DayMath.shortDate), place.isEmpty ? "surgery" : place].compactMap { $0 }
                .joined(separator: " \u{00B7} ")
        case .visit, .paper: return row.date.map(DayMath.shortDate) ?? ""
        }
    }

    func isPicked(_ row: ImportRow) -> Bool { pickedImports.contains(row.id) }

    func toggleImport(_ row: ImportRow) {
        if pickedImports.contains(row.id) { pickedImports.remove(row.id) } else { pickedImports.insert(row.id) }
    }

    // everything found starts picked, the patient takes out what is not theirs
    func offerImport(_ found: DraftPlan, papers: [RecordPaper] = [], from source: ImportSource) {
        draft = found
        recordDraft = nil
        applyImportedKind()
        importSource = source
        importPapers = papers
        importRows = ImportPicks.rows(for: found, papers: papers)
        pickedImports = Set(importRows.map(\.id))
        Motion.run { step = .importPick }
    }

    // only the picked items go on to the check
    func importPicked() {
        guard let found = draft, canImport else { return }
        let kept = ImportPicks.apply(picked: pickedImports, to: found)
        let papers = ImportPicks.pickedPapers(pickedImports, from: importPapers)
        guard !papers.isEmpty else {
            checkItems(of: kept)
            return
        }
        // papers take the scan path: who gave it, what the ai will see, then the check
        recordDraft = kept
        draft = nil
        if hospitalText.isEmpty { hospitalText = kept.hospitalName }
        Task { await read(papers.map { ScannedPage(text: $0.text) }) }
    }

    // back to where the papers come from, nothing is kept
    func leaveImport() {
        draft = nil
        recordDraft = nil
        importRows = []
        importPapers = []
        pickedImports = []
        Motion.run { step = isAddingPapers ? .addPapers : .welcome }
        showsSources = true
    }

    // a MyChart or Health import has no label, so the surgery date it holds says which papers they are
    private func applyImportedKind() {
        guard draft != nil else { return }
        paper = PaperClues.kind(importedSurgeryDate: draft?.surgeryDate, now: AppClock.now(), usual: usualPaper)
        draft?.paper = paper
    }
}
