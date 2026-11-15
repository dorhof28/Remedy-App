//
//  WhatChangedViewModel.swift
//  Remedy
//
//  what the newest paper changed in the plan, both looks
//

import Foundation

// one medicine line in a section
struct WhatChangedRow: Identifiable {
    let id: Int
    let title: String
    // the paper's own words
    let quote: String
}

// one list on screen
struct WhatChangedSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tone: Tone
    let explanation: String
    let rows: [WhatChangedRow]
    // true for medicines the new paper left out
    let asksCareTeam: Bool
}

// the what changed screen after a new paper joins the plan
struct WhatChangedViewModel {

    let sections: [WhatChangedSection]

    static let screenTitle = "What changed"
    static let planRowTitle = "What your newest paper changed"
    static let askCareTeamText = "Ask your care team"
    static let nextTitle = "Next"
    static let doneTitle = "Done"

    // nil on the first paper, or when the newest paper changed no medicines
    init?(plan: CarePlan?) {
        guard let plan, plan.papers.count > 1, let newest = plan.papers.max(by: { $0.addedAt < $1.addedAt }) else { return nil }
        // the plan as it was before the newest paper
        let after = PaperCheckInput(plan: plan).items
        let changes = WhatChanged(before: after.filter { $0.paperID != newest.id }, after: after)

        let all = [
            Self.section("new", "New", "plus.circle.fill", .info,
                         "Your newest paper adds these.", changes.new),
            Self.section("changed", "Changed", "arrow.triangle.2.circlepath", .caution,
                         "Your newest paper says something different about these.", changes.changed),
            Self.section("restarted", "Restarted", "arrow.clockwise.circle.fill", .good,
                         "You were told to stop these. Your newest paper says to take them again.", changes.restarted),
            Self.section("stillStopped", "Still stopped", "nosign", .stop,
                         "Keep not taking these.", changes.stillStopped),
            Self.section("notMentioned", "Not mentioned", "questionmark.circle.fill", .caution,
                         "Your newest paper does not say anything about these.", changes.notMentioned, asks: true),
        ]
        sections = all.filter { !$0.rows.isEmpty }
        if sections.isEmpty { return nil }
    }

    private static func section(_ id: String, _ title: String, _ symbol: String, _ tone: Tone,
                                _ explanation: String, _ items: [CheckItem], asks: Bool = false) -> WhatChangedSection {
        WhatChangedSection(id: id, title: title, symbol: symbol, tone: tone, explanation: explanation,
                           rows: items.map { WhatChangedRow(id: $0.id, title: $0.name, quote: $0.quote) },
                           asksCareTeam: asks)
    }

}
