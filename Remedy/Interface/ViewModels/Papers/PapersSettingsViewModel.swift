//
//  PapersSettingsViewModel.swift
//  Remedy
//
//  words and rows for the Papers screen in Settings
//

import Foundation

// the papers page in settings, with removing a set
struct PapersSettingsViewModel {

    let plan: CarePlan?

    let title = "Papers"
    let addTitle = "Add papers"
    let addFooter = "Add your discharge papers after surgery. You check each new item first."
    let emptyTitle = "No papers yet"
    let removeTitle = "Remove"

    var hasPlan: Bool { plan != nil }

    // newest first
    var papers: [Paper] {
        (plan?.papers ?? []).sorted { $0.sortDate > $1.sortDate }
    }

    // value at the right of the Settings row
    var rowValue: String {
        let count = plan?.papers.count ?? 0
        return count == 0 ? "" : "\(count)"
    }

    static func kindTitle(_ kind: PaperKind) -> String {
        kind == .beforeSurgery ? "Before surgery" : "After surgery"
    }

    static func sourceTitle(_ paper: Paper) -> String {
        switch paper.source {
        case .surgeryTeam: return "Surgery team"
        case .specialist:
            let field = paper.field.map { $0 == .other && !paper.otherKindText.isEmpty ? paper.otherKindText : $0.rawValue.capitalized }
            return field.map { "Specialist, \($0)" } ?? "Specialist"
        case .primaryCare: return "Primary care"
        case .hospitalRecord: return "Hospital record"
        case .other: return "Other"
        }
    }

    func rowTitle(_ paper: Paper) -> String { Self.kindTitle(paper.kind) }

    // source, doctor and date on one line
    func rowDetail(_ paper: Paper) -> String {
        var parts = [Self.sourceTitle(paper)]
        if let doctor = paper.doctorName, !doctor.isEmpty { parts.append(doctor) }
        parts.append(paper.sortDate.formatted(.dateTime.month(.abbreviated).day().year()))
        return parts.joined(separator: " \u{00B7} ")
    }

    // says how many items go with the paper before it is removed
    func removeMessage(for paper: Paper) -> String {
        let count = plan.map { PaperActions.itemCount(of: paper, in: $0) } ?? 0
        return count == 0 ? "This removes these papers from your plan."
                          : "This removes these papers and the \(PlainText.count(count, "item")) read from them."
    }
}
