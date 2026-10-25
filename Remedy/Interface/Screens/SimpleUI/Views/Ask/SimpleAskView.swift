//
//  SimpleAskView.swift
//  Remedy
//
//  simple ask and the answer screen
//

import SwiftUI
import SwiftData

struct SimpleAskView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Environment(\.modelContext) private var context

    // UI only what's typed and whether the answer screen is open
    @State private var draft = ""
    @State private var isShowingAnswer = false
    // UI only is an answer still coming
    @State private var isThinking = false

    var body: some View {
        let viewModel = AskViewModel(plan: plans.first, messages: messages, now: AppClock.now())
        SimpleScreen(title: "Ask a question") {
            Text(viewModel.introDetail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            ForEach(viewModel.simpleSuggestions, id: \.self) { question in
                Button(question) { send(question, viewModel) }
                    .buttonStyle(SimpleButtonStyle(kind: .plain))
            }

            HStack(spacing: 10) {
                TextField(viewModel.prompt, text: $draft)
                    .font(.title3)
                    .submitLabel(.send)
                    .onSubmit { send(draft, viewModel) }
                    .padding(16)
                    .cardStyle()
                Button {
                    send(draft, viewModel)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(viewModel.canSend(draft) ? Color.remedyTeal : Color.inactive)
                }
                .disabled(!viewModel.canSend(draft) || isThinking)
                .accessibilityLabel(viewModel.sendLabel)
            }

            if isThinking {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(viewModel.thinkingText)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)

            Text(viewModel.footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationDestination(isPresented: $isShowingAnswer) {
            SimpleAnswerView()
        }
    }

    // saves the question waits for the answer then opens the answer screen
    private func send(_ text: String, _ viewModel: AskViewModel) {
        guard viewModel.canSend(text), !isThinking,
              let question = viewModel.saveQuestion(text, in: context) else { return }
        draft = ""
        isThinking = true
        Task {
            if let answer = await viewModel.findAnswer(to: question) {
                viewModel.saveAnswer(answer, in: context)
            }
            isThinking = false
            isShowingAnswer = true
        }
    }
}

// MARK: - The answer, on its own screen

// the answer on its own screen
struct SimpleAnswerView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Environment(\.dismiss) private var dismiss

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
                    Text(answer.text)
                        .font(.title3)
                        .minimumScaleFactor(0.8)
                    if answer.showsQuote {
                        Divider()
                        PaperQuoteCard(quote: answer.quote, source: answer.quoteSource)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(answer.tone == .neutral ? Color.cardBackground : answer.tone.color.opacity(0.12))

                Spacer(minLength: 0)

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
                .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
            }
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleAskView() }
}
