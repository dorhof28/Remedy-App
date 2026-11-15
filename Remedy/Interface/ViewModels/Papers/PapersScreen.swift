//
//  PapersScreen.swift
//  Remedy
//
//  words for papers (screen 46), one paper (screen 47) and what changed (screen 48)
//

import Foundation
import SwiftData

// the papers list: each set, its pages and the check
struct PapersScreen {
    let plan: CarePlan?
    let now: Date

    let title = "Papers"
    let listTitle = "Your papers"
    let addTitle = "Add Papers"
    let addSubtitle = "Camera, photos, PDF, MyChart, Apple Health"
    let footer = "Each new paper goes through \u{201C}What the AI will see\u{201D} and the check, item by item. Open a paper to see its pages or delete it."
    let emptyText = "No papers yet."
    let disagreeTitle = "Your papers disagree"
    let notesTitle = "Notes from the check"

    private let list: PapersSettingsViewModel
    private let check: PaperCheckViewModel

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        self.list = PapersSettingsViewModel(plan: plan)
        self.check = PaperCheckViewModel(plan: plan, now: now)
    }

    var papers: [Paper] { list.papers }

    // "Your newest paper changed 3 things", nil when nothing changed
    var changedTitle: String? {
        guard let changes = WhatChangedViewModel(plan: plan) else { return nil }
        let count = changes.sections.filter { $0.id != "stillStopped" }.reduce(0) { $0 + $1.rows.count }
        return "Your newest paper changed \(PlainText.count(count, "thing"))"
    }
    let changedSubtitle = "See what changed"

    // disagreements are never hidden
    var disagreeCards: [PaperCheckCardData] { check.redCards }
    var noteCount: Int { check.blueNotes.count }

    static func title(_ paper: Paper) -> String {
        switch paper.source {
        case .specialist:
            let field = paper.field.map { $0 == .other && !paper.otherKindText.isEmpty ? paper.otherKindText : $0.rawValue }
            return field.map { "\(PlainText.upperFirst($0)) doctor note" } ?? "Specialist note"
        case .primaryCare: return "Primary care note"
        case .hospitalRecord: return "Hospital record"
        default: return PapersSettingsViewModel.kindTitle(paper.kind)
        }
    }

    // "Lakeside surgery team · Tue, Nov 10 · 3 pages"
    func subtitle(_ paper: Paper) -> String {
        var parts: [String] = []
        if let doctor = paper.doctorName, !doctor.isEmpty { parts.append(doctor) }
        else if let hospital = paper.hospitalName, !hospital.isEmpty { parts.append("\(hospital) surgery team") }
        else { parts.append(PapersSettingsViewModel.sourceTitle(paper)) }
        parts.append(DayMath.shortDate(paper.sortDate))
        let pages = pageCount(paper)
        if pages > 0 { parts.append(PlainText.count(pages, "page")) }
        return parts.joined(separator: " \u{00B7} ")
    }

    func pageCount(_ paper: Paper) -> Int {
        (plan?.documents ?? []).filter { $0.paperID == paper.id }.count
    }
}

// one paper (screen 47)
struct PaperScreen {
    let paper: Paper
    let plan: CarePlan?
    let now: Date

    let fromTitle = "From this paper"
    let deleteTitle = "Delete This Paper"
    let footer = "Deleting asks first and removes everything that came only from this paper."
    let pageWord = "Page"

    var title: String {
        PapersScreen.title(paper).split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // "Lakeside surgery team · Tue, Nov 10"
    var subtitle: String {
        let screen = PapersScreen(plan: plan, now: now)
        return screen.subtitle(paper).components(separatedBy: " \u{00B7} ").prefix(2).joined(separator: " \u{00B7} ")
    }

    var pageNumbers: [Int] {
        (plan?.documents ?? []).filter { $0.paperID == paper.id }.map(\.pageNumber).sorted()
    }

    private var id: UUID { paper.id }
    var medicineCount: Int { (plan?.medicines ?? []).filter { $0.paperID == id }.count }
    var ruleCount: Int { (plan?.rules ?? []).filter { $0.paperID == id }.count }
    var visitCount: Int { (plan?.appointments ?? []).filter { $0.paperID == id }.count }
    var taskCount: Int { (plan?.tasks ?? []).filter { $0.paperID == id }.count }

    // "5 medicines", "4 rules, 3 visits"
    var medicinesTitle: String { PlainText.count(medicineCount, "medicine") }
    let medicinesSubtitle = "See them in Medicines"
    var planTitle: String {
        [PlainText.count(ruleCount, "rule"), PlainText.count(visitCount, "visit"),
         taskCount == 0 ? "" : PlainText.count(taskCount, "to-do")]
            .filter { !$0.isEmpty }.joined(separator: ", ")
    }
    let planSubtitle = "See them in Plan"
    let changedTitle = "What Changed"
    let changedSubtitle = "Compared with your earlier papers"
    var showsChanged: Bool {
        guard let newest = plan?.papers.max(by: { $0.addedAt < $1.addedAt }) else { return false }
        return newest.id == paper.id && WhatChangedViewModel(plan: plan) != nil
    }

    var deleteMessage: String { PapersSettingsViewModel(plan: plan).removeMessage(for: paper) }
}

extension WhatChangedViewModel {
    // "After-surgery paper, Tue, Nov 10, compared with your plan."
    static func intro(plan: CarePlan?) -> String {
        guard let newest = plan?.papers.max(by: { $0.addedAt < $1.addedAt }) else { return "" }
        let kind = newest.kind == .beforeSurgery ? "Before-surgery paper" : "After-surgery paper"
        return "\(kind), \(DayMath.shortDate(newest.sortDate)), compared with your plan."
    }

    static let footer = "Something not mentioned on a new paper is never restarted on its own."

    // 48 says why the newer paper wins, only for the surgery team case the check also follows (rule 5)
    static func footer(plan: CarePlan?) -> String {
        let papers = (plan?.papers ?? []).sorted { $0.addedAt > $1.addedAt }
        guard papers.count >= 2, papers[0].isSurgeryTeam else { return footer }
        let facts = { (paper: Paper) in
            NewerPaperRule.PaperFacts(giver: paper.isSurgeryTeam ? .surgeonsOffice : .anotherDoctor, printed: paper.printedDate)
        }
        let outcome = NewerPaperRule.decide(facts(papers[1]), facts(papers[0]))
        guard outcome == .newerWins(.fromSurgeryTeam) else { return footer }
        return NewerPaperRule.explanation(outcome, newerGiver: .surgeonsOffice, daysApart: nil)
    }
}
