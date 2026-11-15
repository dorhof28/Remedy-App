//
//  ImportPickView.swift
//  Remedy
//
//  screen 5 what mychart or apple health found, the patient picks what comes in
//

import SwiftUI

// tick what to keep from mychart or health, both looks use it
struct ImportPickView: View {
    @Bindable var viewModel: ScanFlowViewModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            if !viewModel.importVisitRows.isEmpty {
                Section {
                    rows(viewModel.importVisitRows)
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                        intro
                        ListSectionHeader(title: viewModel.importVisitsHeader)
                    }
                }
            }
            if !viewModel.importPaperRows.isEmpty {
                Section {
                    rows(viewModel.importPaperRows)
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                        if viewModel.importVisitRows.isEmpty { intro }
                        ListSectionHeader(title: viewModel.importPapersHeader)
                    }
                }
            }
            if !viewModel.importMedicineRows.isEmpty {
                Section {
                    rows(viewModel.importMedicineRows)
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                        // the intro tops the page when nothing comes before it
                        if viewModel.importVisitRows.isEmpty && viewModel.importPaperRows.isEmpty { intro }
                        ListSectionHeader(title: viewModel.importMedicinesHeader)
                    }
                } footer: {
                    footer
                }
            } else {
                Section { } footer: { footer }
            }
            // at accessibility sizes the button ends the page instead of covering it
            if typeSize.isAccessibilitySize {
                Section { importButton.plainListRow() }
            }
        }
        .remedyList()
        .navigationTitle(viewModel.importTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { viewModel.leaveImport() } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left"); Text(viewModel.backButton) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                importButton
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $viewModel.showsSources) { PaperSourceSheet(viewModel: viewModel) }
    }

    // a tap picks or unpicks, the tile shows a check or an empty circle
    private func rows(_ rows: [ImportRow]) -> some View {
        ForEach(rows) { row in
            let picked = viewModel.isPicked(row)
            Button { viewModel.toggleImport(row) } label: {
                ListRow(symbol: picked ? "checkmark.circle" : "circle", tone: picked ? .info : .neutral,
                        title: row.title, subtitle: viewModel.importSubtitle(row))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
        }
    }

    // a header, not a row, so the rounded row edge never clips it
    private var intro: some View {
        Text(viewModel.importDetail)
            .font(.title3)
            .foregroundStyle(Color.ink2)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, -16)
    }

    private var footer: some View {
        Text(viewModel.importFooter)
            .font(.subheadline)
            .foregroundStyle(Color.ink2)
            .textCase(nil)
    }

    private var importButton: some View {
        PrimaryButton(title: viewModel.importButton) { viewModel.importPicked() }
            .disabled(!viewModel.canImport)
    }
}
