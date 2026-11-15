//
//  ConnectionCheckView.swift
//  Remedy
//
//  check connections (109): mychart and health, for testing, opened from demo mode
//

import SwiftUI

// checks mychart and health before a demo, test builds only
struct ConnectionCheckView: View {
    @State private var viewModel = ConnectionCheckViewModel()

    var body: some View {
        List {
            Section {
                ForEach(viewModel.sourceRows) { row in
                    if viewModel.isRunning {
                        HStack(spacing: 12) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).foregroundStyle(Color.ink)
                                Text(viewModel.checkingText).font(.subheadline).foregroundStyle(Color.ink2)
                            }
                        }
                        .frame(minHeight: Spacing.minTarget)
                    } else {
                        ListRow(symbol: row.isOK ? "checkmark.circle" : "exclamationmark.triangle",
                                tone: row.isOK ? .good : .caution, title: row.title, subtitle: row.detail)
                            .accessibilityElement(children: .combine)
                    }
                }
            } footer: {
                Text(viewModel.pageFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(viewModel.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: viewModel.checkAgainTitle) { Task { await viewModel.run() } }
                .disabled(viewModel.isRunning)
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.vertical, 10)
        }
        .task { await viewModel.run() }
    }
}
