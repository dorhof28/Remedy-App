//
//  ConnectionCheckView.swift
//  Remedy
//
//  settings screen that shows if mychart and health work
//

import SwiftUI

struct ConnectionCheckView: View {
    @State private var viewModel = ConnectionCheckViewModel()

    var body: some View {
        List {
            Section {
                ForEach(viewModel.results) { result in
                    HStack(spacing: 12) {
                        Image(systemName: result.isOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(result.isOK ? Tone.good.color : Tone.caution.color)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.body)
                            Text(result.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if viewModel.isRunning {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text(viewModel.passedText)
            } footer: {
                Text(viewModel.footer)
            }

            Section {
                Button(viewModel.runTitle) {
                    Task { await viewModel.run() }
                }
                .disabled(viewModel.isRunning)
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.run() }
    }
}
