//
//  PaperSourceLine.swift
//  Remedy
//
//  "From: ..." line for a detail card, shared by both looks
//

import Foundation

// the from your paper line under a quote
enum PaperSourceLine {

    // nil when there is no paper (old saved plans)
    static func text(for paper: Paper?) -> String? {
        guard let paper else { return nil }
        let date = paper.printedDate.map { "printed " + dateFormatter.string(from: $0) } ?? "no date on the paper"
        return "From: \(who(paper)), \(date)"
    }

    // look the paper up in the plan by its id
    static func text(paperID: UUID?, in plan: CarePlan?) -> String? {
        guard let paperID, let paper = plan?.papers.first(where: { $0.id == paperID }) else { return nil }
        return text(for: paper)
    }

    private static func who(_ paper: Paper) -> String {
        switch paper.source {
        case .surgeryTeam: return "your surgeon or the hospital"
        case .primaryCare: return "your family doctor"
        case .hospitalRecord: return "your hospital record"
        case .other: return "another paper"
        case .specialist:
            let kind: String
            switch paper.field {
            case .heart: kind = "Heart doctor"
            case .kidney: kind = "Kidney doctor"
            case .blood: kind = "Blood doctor"
            case .diabetes: kind = "Diabetes doctor"
            case .lungs: kind = "Lung doctor"
            case .other, .none: kind = "Specialist"
            }
            guard let name = paper.doctorName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return kind }
            // a name like Drake is not a title
            let lower = name.lowercased()
            let hasTitle = lower == "dr" || lower.hasPrefix("dr ") || lower.hasPrefix("dr.")
            let full = hasTitle ? name : "Dr. " + name
            return "\(kind) (\(full))"
        }
    }

    // "Dec 1 2026"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d yyyy"
        return formatter
    }()
}
