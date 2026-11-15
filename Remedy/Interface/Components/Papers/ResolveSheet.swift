//
//  ResolveSheet.swift
//  Remedy
//
//  screen 17 which paper the office said is right, and who said it, then save
//

import SwiftUI
import SwiftData

// the office told me which one: pick the paper and save what they said
struct ResolveSheet: View {
    let card: PaperCheckCardData
    // kept for the simple look, it uses the same sheet at its own sizes
    var large = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // UI only what is picked and typed
    @State private var chosen: UUID?
    @State private var who: String?
    @State private var someoneElse = ""
    @State private var officeSaid = ""
    @State private var showsPickProblem = false

    private var whoText: String {
        who == DisagreeWords.someoneElse ? someoneElse : (who ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(card.quotes) { quote in
                        Button {
                            chosen = quote.id
                            showsPickProblem = false
                        } label: {
                            ListRow(title: "\u{201C}\(quote.text)\u{201D}", subtitle: DisagreeWords.paperLine(quote)) { EmptyView() }
                                .leadingMark(chosen == quote.id ? "largecircle.fill.circle" : "circle", isOn: chosen == quote.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen == quote.id ? .isSelected : [])
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DisagreeWords.question(card))
                            .font(.title3)
                            .foregroundStyle(Color.ink2)
                            .textCase(nil)
                            .padding(.leading, -16)
                        if showsPickProblem {
                            Text(DisagreeWords.pickProblem)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.dangerInk)
                                .textCase(nil)
                                .padding(.leading, -16)
                        }
                    }
                }

                Section {
                    ForEach(DisagreeWords.offices(card) + [DisagreeWords.someoneElse], id: \.self) { name in
                        Button { who = name } label: {
                            ListRow(title: name) { EmptyView() }
                                .leadingMark(who == name ? "largecircle.fill.circle" : "circle", isOn: who == name)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(who == name ? .isSelected : [])
                    }
                    if who == DisagreeWords.someoneElse {
                        TextField(DisagreeWords.someoneElse, text: $someoneElse, prompt: Text("Like Nurse Kim"))
                            .font(.body)
                            .frame(minHeight: Spacing.minTarget)
                    }
                    TextField(DisagreeWords.notePrompt, text: $officeSaid, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.body)
                        .frame(minHeight: Spacing.minTarget)
                } header: {
                    ListSectionHeader(title: DisagreeWords.whoHeader)
                } footer: {
                    Text(DisagreeWords.footer(who: whoText, now: AppClock.now()))
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                }
            }
            .remedyList()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(DisagreeWords.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(PaperCheckViewModel.cancelTitle) { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: PaperCheckViewModel.saveTitle, action: save)
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.bottom, 8)
            }
        }
        .presentationDetents([.large])
    }

    // nothing picked shows the sentence instead of saving
    private func save() {
        guard let chosen else {
            showsPickProblem = true
            return
        }
        PaperCheckViewModel.save(card, chosen: chosen, officeSaid: officeSaid, whoSaid: whoText, in: context)
        dismiss()
    }
}
