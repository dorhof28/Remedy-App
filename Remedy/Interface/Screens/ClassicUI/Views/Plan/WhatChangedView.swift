//
//  WhatChangedView.swift
//  Remedy
//
//  classic what changed (screen 48): new, changed, restarted, still stopped and not mentioned
//

import SwiftUI

// classic what changed page
struct WhatChangedView: View {
    let viewModel: WhatChangedViewModel
    var intro: String = ""
    var footer: String = WhatChangedViewModel.footer
    var onDone: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !intro.isEmpty {
                Section {
                    Text(intro).font(.body).foregroundStyle(Color.ink2).plainListRow()
                }
            }
            ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                Section {
                    ForEach(section.rows) { row in
                        ListRow(symbol: Self.symbol(section.id), tone: section.tone, title: row.title,
                                subtitle: row.quote.isEmpty ? section.explanation : row.quote)
                            .accessibilityElement(children: .combine)
                    }
                    if section.asksCareTeam {
                        Text(WhatChangedViewModel.askCareTeamText)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(section.tone.color)
                            .frame(minHeight: Spacing.minTarget, alignment: .leading)
                    }
                } header: {
                    ListSectionHeader(title: section.title)
                } footer: {
                    if index == viewModel.sections.count - 1 {
                        Text(footer).font(.footnote).foregroundStyle(Color.ink2)
                    }
                }
            }
        }
        .remedyList()
        .navigationTitle("What Changed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: WhatChangedViewModel.doneTitle) { if let onDone { onDone() } else { dismiss() } }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.vertical, 10)
        }
    }

    // plain outline icons from the design
    static func symbol(_ id: String) -> String {
        switch id {
        case "new": return "plus"
        case "changed": return "arrow.uturn.backward"
        case "restarted": return "arrow.clockwise"
        case "stillStopped": return "nosign"
        default: return "questionmark.circle"
        }
    }
}
