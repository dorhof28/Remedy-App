//
//  ConfirmView.swift
//  Remedy
//
//  check the plan one item at a time
//

import SwiftUI

struct ConfirmView: View {
    let viewModel: ScanFlowViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // UI only the edit sheet
    @State private var edit: ConfirmEdit?

    var body: some View {
        VStack(spacing: 12) {
            // progress
            VStack(spacing: 6) {
                Text(viewModel.confirmHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SegmentBar(total: viewModel.progressTotal, filled: viewModel.cardIndex + 1, tone: .info)
            }
            .padding(.horizontal, Spacing.screenEdge)

            ScrollView {
                if let card = viewModel.currentCard {
                    ConfirmCardView(card: card)
                        .id(card.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                        .padding(.horizontal, Spacing.screenEdge)
                }
            }

            // answers
            VStack(spacing: 10) {
                Button {
                    viewModel.looksRight()
                } label: {
                    Label(viewModel.looksRightButton, systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                HStack(spacing: 10) {
                    Button {
                        edit = viewModel.editValues()
                    } label: {
                        Label(viewModel.editButton, systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    Button(role: .destructive) {
                        viewModel.notOnPapers()
                    } label: {
                        Label(viewModel.removeButton, systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 8)
            .sensoryFeedback(.selection, trigger: viewModel.cardIndex)
        }
        .navigationTitle(viewModel.progressText)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            if viewModel.canGoBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(viewModel.backButton, systemImage: "chevron.left") { viewModel.back() }
                }
            }
        }
        .sheet(isPresented: Binding(get: { edit != nil }, set: { if !$0 { edit = nil } })) {
            if let start = edit {
                ConfirmEditSheet(viewModel: viewModel, edit: start) { saved in
                    viewModel.saveEdit(saved)
                    edit = nil
                }
            }
        }
    }
}

// MARK: - One card

// one item to check
struct ConfirmCardView: View {
    let card: ConfirmCard

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardEyebrow(text: card.eyebrow, symbol: card.symbol, tone: card.tone)
                Text(card.title)
                    .font(.title2.bold())
                InfoRows(rows: card.facts)
                Divider()
                PaperQuoteCard(quote: card.quote, source: card.quoteSource)
            }
        }
    }
}

// MARK: - Edit sheet

// fix an item
struct ConfirmEditSheet: View {
    let viewModel: ScanFlowViewModel
    @State var edit: ConfirmEdit
    let onSave: (ConfirmEdit) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $edit.title)
                }
                if edit.showsDays {
                    Section {
                        Toggle("Has a start day", isOn: $edit.hasStart)
                        if edit.hasStart {
                            Stepper(viewModel.dayWords(edit.startDay), value: $edit.startDay, in: -30...60)
                        }
                        Toggle("Has an end day", isOn: $edit.hasEnd)
                        if edit.hasEnd {
                            Stepper(viewModel.dayWords(edit.endDay), value: $edit.endDay, in: -30...60)
                        }
                    } header: {
                        Text("When")
                    } footer: {
                        Text("Change these only if they don\u{2019}t match your papers.")
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(edit) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
