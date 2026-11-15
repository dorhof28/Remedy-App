//
//  ConfirmView.swift
//  Remedy
//
//  check the plan one item at a time
//

import SwiftUI

// one card per item, the patient says if it matches the paper
struct ConfirmView: View {
    @Bindable var viewModel: ScanFlowViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    // UI only the edit sheet
    @State private var edit: ConfirmEdit?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: viewModel.checkProgressValue, total: viewModel.checkProgressTotal)
                        .tint(Color.remedyTeal)
                    Text(viewModel.checkProgressText)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                        .monospacedDigit()
                }
                if viewModel.isAskingPhoneGap {
                    phoneGap.transition(.slideIn(reduceMotion: reduceMotion))
                } else {
                    if let card = viewModel.currentCard {
                        VStack(alignment: .leading, spacing: 16) {
                            ConfirmCardView(card: card)
                            if !card.quote.isEmpty {
                                PaperQuote(source: card.quoteSource, quote: "\u{201C}\(card.quote)\u{201D}", plain: card.plainWords)
                            }
                        }
                        .id(card.id)
                        .transition(.slideIn(reduceMotion: reduceMotion))
                    }
                    if let question = viewModel.amPmQuestion {
                        PaperQuestionCard(eyebrow: viewModel.questionEyebrow, question: viewModel.amPmText,
                                          choices: [(viewModel.morningButton, question.am), (viewModel.eveningButton, question.pm)],
                                          picked: question.picked, changeTitle: viewModel.changeAnswerButton,
                                          onPick: { viewModel.pickLastGiven($0) }, onChange: { viewModel.clearLastGiven() })
                    }
                    if let question = viewModel.hospitalDoseQuestion() {
                        PaperQuestionCard(eyebrow: viewModel.questionEyebrow, question: question.title,
                                          choices: [(question.yesButton, true), (question.noButton, false)],
                                          picked: question.answer, changeTitle: viewModel.changeAnswerButton,
                                          onPick: { viewModel.answerHospitalDose($0) }, onChange: { viewModel.clearHospitalDose() })
                    }
                }
                // at accessibility sizes the buttons end the page instead of covering it
                if typeSize.isAccessibilitySize { answers }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 24)
        }
        .background(Color.screenBackground)
        .safeAreaInset(edge: .bottom) { if !typeSize.isAccessibilitySize { answers } }
        .navigationTitle(viewModel.confirmTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            if viewModel.canGoBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button { viewModel.back() } label: {
                        HStack(spacing: 4) { Image(systemName: "chevron.left"); Text(viewModel.backButton) }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.cardIndex)
        .onAppear { viewModel.startCheckGaps() }
        .sheet(isPresented: Binding(get: { edit != nil }, set: { if !$0 { edit = nil } })) {
            if let start = edit {
                ConfirmEditSheet(viewModel: viewModel, edit: start) { saved in
                    viewModel.saveEdit(saved)
                    edit = nil
                }
            }
        }
    }

    // this is right first, fix and leave out side by side under it
    @ViewBuilder
    private var answers: some View {
        VStack(spacing: 12) {
            if viewModel.isAskingPhoneGap {
                PrimaryButton(title: viewModel.addNumberButton, symbol: "phone.fill") { viewModel.savePhoneGap() }
                    .disabled(!ScanFlowViewModel.isPhone(viewModel.gapPhone))
                SecondaryButton(title: viewModel.skipButton) { viewModel.skipPhoneGap() }
            } else if viewModel.waitsForAnswer {
                // never guessed, This Is Right waits for the answer
                SecondaryButton(title: viewModel.looksRightButton, symbol: "checkmark", symbolTone: .neutral) {}
                    .disabled(true)
                Text(viewModel.answerFirstNote)
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
            } else {
                PrimaryButton(title: viewModel.looksRightButton, symbol: "checkmark") { viewModel.looksRight() }
                let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    SecondaryButton(title: viewModel.editButton) { edit = viewModel.editValues() }
                    SecondaryButton(title: viewModel.removeButton) { viewModel.notOnPapers() }
                        .accessibilityHint(viewModel.removeSpoken)
                }
            }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 8)
    }

    // 87, the missing phone number with its own field
    private var phoneGap: some View {
        VStack(alignment: .leading, spacing: 12) {
            ActionCard(style: .caution, eyebrow: viewModel.gapEyebrow, eyebrowSymbol: "exclamationmark.triangle",
                       title: viewModel.phoneGapTitle, text: viewModel.phoneGapText)
            HStack(spacing: 16) {
                Text(viewModel.phoneFieldLabel).foregroundStyle(Color.ink2)
                TextField(viewModel.phoneFieldLabel, text: $viewModel.gapPhone, prompt: Text("(555) 010-0142"))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            .font(.body)
            .padding(.horizontal, Spacing.insideCard)
            .frame(minHeight: Spacing.rowMin)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
            Text(viewModel.phoneGapFooter)
                .font(.footnote)
                .foregroundStyle(Color.ink2)
                .padding(.horizontal, Spacing.insideCard)
        }
    }
}

// MARK: - A question the paper doesn't answer

// 88, two pill answers, then the answer with Change
struct PaperQuestionCard<Value: Equatable>: View {
    let eyebrow: String
    let question: String
    let choices: [(title: String, value: Value)]
    let picked: Value?
    let changeTitle: String
    let onPick: (Value) -> Void
    let onChange: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(eyebrow, systemImage: "questionmark.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentInk)
            Text(question)
                .font(.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let picked, let answer = choices.first(where: { $0.value == picked }) {
                HStack {
                    Label(answer.title, systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentInk)
                    Spacer()
                    Button(changeTitle, action: onChange)
                        .font(.body)
                        .foregroundStyle(Color.accentInk)
                        .frame(minHeight: Spacing.minTarget)
                }
            } else {
                let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    ForEach(choices.indices, id: \.self) { index in
                        SecondaryButton(title: choices[index].title) { onPick(choices[index].value) }
                    }
                }
            }
        }
        .padding(Spacing.insideCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - One card

// one item to check: what to do, the name, then each fact on its own line
struct ConfirmCardView: View {
    let card: ConfirmCard

    private var style: ActionCard<FactRows>.Style {
        switch card.tone {
        case .stop: return .stop
        case .caution: return .caution
        default: return .plain
        }
    }

    var body: some View {
        ActionCard(style: style, eyebrow: card.eyebrow, eyebrowSymbol: card.symbol, title: card.title,
                   subtitle: card.subtitle, text: card.text) {
            FactRows(rows: card.facts)
        }
    }
}

extension View {
}

// MARK: - Edit sheet

// fix an item
struct ConfirmEditSheet: View {
    let viewModel: ScanFlowViewModel
    @State var edit: ConfirmEdit
    let onSave: (ConfirmEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $edit.title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { nameFocused = false }
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
            .scrollDismissesKeyboard(.interactively)
            .remedyFieldsInList()
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseButton { dismiss() }
                SheetCapsuleButton(title: "Save") { onSave(edit) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Radius.large)
    }
}
