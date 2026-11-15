//
//  SimpleWhatChangedView.swift
//  Remedy
//
//  simple look of what the newest paper changed, one list on each screen
//

import SwiftUI
import SwiftData

// simple what changed
struct SimpleWhatChangedView: View {
    let viewModel: WhatChangedViewModel
    var footer: String = WhatChangedViewModel.footer

    @Environment(\.dismiss) private var dismiss
    // UI only which list is showing
    @State private var index = 0

    private var section: WhatChangedSection { viewModel.sections[index] }
    private var isLast: Bool { index == viewModel.sections.count - 1 }

    var body: some View {
        SimpleScreen(title: section.title) {
            Label(section.explanation, systemImage: section.symbol)
                .font(.title3)
                .foregroundStyle(section.tone.color)
            if section.asksCareTeam {
                Text(WhatChangedViewModel.askCareTeamText)
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
            }
            SimplePagedList(items: section.rows) { row in
                SimplePlanRow(kind: .custom(symbol: section.symbol, tone: section.tone), title: row.title, detail: row.quote)
            }
            .id(section.id)
            if isLast {
                Text(footer)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if isLast { dismiss() } else { index += 1 }
            } label: {
                Label(isLast ? WhatChangedViewModel.doneTitle : WhatChangedViewModel.nextTitle,
                      systemImage: isLast ? "checkmark" : "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .buttonStyle(SimpleButtonStyle())
            .padding(Spacing.simpleEdge)
        }
    }
}

// the menu's page, reads the newest change from the saved plan
struct SimpleWhatChangedPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        if let changes = WhatChangedViewModel(plan: plans.first) {
            SimpleWhatChangedView(viewModel: changes, footer: WhatChangedViewModel.footer(plan: plans.first))
        } else {
            SimpleScreen(title: WhatChangedViewModel.planRowTitle) {
                Text("Nothing has changed since your first paper.")
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
            }
        }
    }
}
