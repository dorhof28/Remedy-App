//
//  InstructionsView.swift
//  Remedy
//
//  classic rules (screen 43): now, later and done, a rule opens its sheet with the paper's words
//

import SwiftUI
import SwiftData

// classic instructions page, grouped by topic
struct InstructionsView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only the rule whose sheet is open
    @State private var openRule: CareRule?

    var body: some View {
        let screen = RulesScreen(plan: plans.first, now: AppClock.now())
        List {
            if screen.groups.isEmpty {
                Section { Text(screen.emptyText).font(.body).foregroundStyle(Color.ink2) }
            }
            ForEach(Array(screen.groups.enumerated()), id: \.element.id) { index, group in
                Section {
                    ForEach(group.lines) { line in
                        Button {
                            if case .rule(let id) = line.target { openRule = plans.first?.rules.first { $0.persistentModelID == id } }
                        } label: {
                            ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                                    showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    ListSectionHeader(title: group.title)
                } footer: {
                    if index == screen.groups.count - 1 {
                        Text(screen.footer).font(.footnote).foregroundStyle(Color.ink2)
                    }
                }
            }
        }
        .remedyList()
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(screen.readAloudButton) { Speaker.toggle(screen.spoken) }
                    .accessibilityHint("Reads the rules out loud. Tap again to stop.")
            }
        }
        .sheet(item: $openRule) { RuleSheet(rule: $0) }
    }
}

// one rule (screen 44): what it says, until when, and the paper's exact words
struct RuleSheet: View {
    let rule: CareRule

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let detail = RuleDetail(rule: rule, now: AppClock.now())
        NavigationStack {
            List {
                Section {
                    ActionCard(style: .plain, eyebrow: detail.eyebrow, eyebrowSymbol: detail.eyebrowSymbol,
                               title: detail.heading, text: detail.text, eyebrowTone: detail.tone)
                        .plainListRow()
                }
                if detail.fromText != nil || detail.untilText != nil {
                    Section {
                        if let from = detail.fromText { ListRow(symbol: "calendar", title: "From", value: from) }
                        if let until = detail.untilText { ListRow(symbol: "calendar", title: "Until", value: until) }
                    }
                }
                if !detail.quote.isEmpty {
                    Section {
                        PaperQuote(source: detail.quoteSource, quote: detail.quote, plain: detail.quotePlain)
                            .plainListRow()
                    }
                }
            }
            .remedyList()
            .navigationTitle(detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(detail.doneButton) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { InstructionsView() }
}
