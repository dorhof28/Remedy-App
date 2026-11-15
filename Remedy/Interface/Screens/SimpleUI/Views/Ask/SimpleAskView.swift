//
//  SimpleAskView.swift
//  Remedy
//
//  simple ask and the answer screen
//

import SwiftUI
import SwiftData

// simple ask
struct SimpleAskView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Environment(\.modelContext) private var context

    // UI only what's typed and whether the answer screen is open
    @State private var draft = ""
    @State private var isShowingAnswer = false
    // UI only is an answer still coming
    @State private var isThinking = false
    @FocusState private var isTyping: Bool

    var body: some View {
        let viewModel = AskViewModel(plan: plans.first, messages: messages, now: AppClock.now())
        SimpleScreen(title: "Ask a question") {
            // the box comes first so the keyboard never covers it
            HStack(spacing: 10) {
                TextField(viewModel.prompt, text: $draft)
                    .font(.title3)
                    .focused($isTyping)
                    .submitLabel(.send)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit { send(draft, viewModel) }
                Button {
                    send(draft, viewModel)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(viewModel.canSend(draft) && !isThinking ? Color.accentFill : Color.inactive)
                        .frame(width: 64, height: 64)
                        .contentShape(Rectangle())
                }
                .disabled(!viewModel.canSend(draft) || isThinking)
                .accessibilityLabel(viewModel.sendLabel)
            }

            // the emergency line sits next to the box, not at the bottom
            if let url = viewModel.emergencyURL {
                Link(destination: url) {
                    Label(viewModel.emergencyLinkTitle, systemImage: "phone.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Tone.stop.color)
                        .frame(minHeight: Spacing.minTarget)
                }
                .accessibilityHint(viewModel.footnote)
            }

            if isThinking {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(viewModel.thinkingText)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                }
                .accessibilityElement(children: .combine)
            }

            ForEach(viewModel.simpleSuggestions, id: \.self) { question in
                Button { send(question, viewModel) } label: {
                    Label(question, systemImage: "questionmark.bubble.fill")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                    .disabled(isThinking)
            }

            Spacer(minLength: 0)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(isPresented: $isShowingAnswer) {
            SimpleAnswerView()
        }
    }

    // saves the question waits for the answer then opens the answer screen
    private func send(_ text: String, _ viewModel: AskViewModel) {
        guard viewModel.canSend(text), !isThinking,
              let question = viewModel.saveQuestion(text, in: context) else { return }
        draft = ""
        isTyping = false
        isThinking = true
        Task {
            if let answer = await viewModel.findAnswer(to: question) {
                viewModel.saveAnswer(answer, in: context)
                isShowingAnswer = true
            }
            isThinking = false
        }
    }
}

// MARK: - The answer, on its own screen

// the answer on its own screen
struct SimpleAnswerView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // UI only is the answer for a tapped medicine still coming
    @State private var isThinking = false

    var body: some View {
        let viewModel = AskViewModel(plan: plans.first, messages: messages, now: AppClock.now())
        SimpleScreen(title: "") {
            if let question = viewModel.lastQuestion {
                Text("\u{201C}\(question.text)\u{201D}")
                    .font(.title2.bold())
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            if let answer = viewModel.lastAnswer {
                VStack(alignment: .leading, spacing: 14) {
                    // the same tinted tile as the classic answer so the meaning shows before the words
                    HStack(alignment: .top, spacing: 14) {
                        if !answer.symbol.isEmpty {
                            ItemIconTile(kind: .custom(symbol: answer.symbol, tone: answer.tone == .neutral ? .info : answer.tone), size: 48)
                                .symbolEffect(.bounce, options: .nonRepeating, value: answer.id)
                        }
                        Text(answer.text)
                            .font(.title3)
                            .minimumScaleFactor(0.8)
                    }
                    if answer.showsQuote {
                        Divider()
                        PaperQuoteCard(quote: answer.quote, source: answer.quoteSource)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(tone: answer.tone)

                Spacer(minLength: 0)

                // which medicine they mean, the answer shows here
                ForEach(answer.choices, id: \.self) { name in
                    Button(name) { choose(name, viewModel) }
                        .buttonStyle(SimpleButtonStyle())
                        .disabled(isThinking)
                }

                if answer.showsCall, let url = answer.callURL {
                    Link(destination: url) {
                        Label(answer.callTitle, systemImage: "phone.fill")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: answer.tone == .stop ? .danger : .primary))
                }
                ReadAloudButton(title: "Read the answer to me", text: answer.text)
                Button {
                    dismiss()
                } label: {
                    Label(viewModel.askAnotherTitle, systemImage: "bubble.left.fill")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain))
            }
        }
    }

    // asks again with the medicine they tapped
    private func choose(_ name: String, _ viewModel: AskViewModel) {
        guard !isThinking, let question = viewModel.saveQuestion(name, in: context) else { return }
        isThinking = true
        Task {
            if let answer = await viewModel.findAnswer(to: question) {
                viewModel.saveAnswer(answer, in: context)
            }
            isThinking = false
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleAskView() }
}
