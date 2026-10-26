//
//  AskView.swift
//  Remedy
//
//  classic ask tab chat
//

import SwiftUI
import SwiftData

struct AskView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only what's typed in the box
    @State private var draft = ""
    // UI only is the "Clear chat?" check showing
    @State private var isConfirmingClear = false
    // UI only is an answer still coming
    @State private var isThinking = false
    @FocusState private var isTyping: Bool

    var body: some View {
        NavigationStack {
            let viewModel = AskViewModel(plan: plans.first, messages: messages, now: AppClock.now())
            content(viewModel)
                .background(Color.screenBackground)
                .navigationTitle(viewModel.title)
                .helpButtons()
                .toolbar {
                    if viewModel.canClear {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(viewModel.clearTitle, systemImage: "trash", role: .destructive) {
                                    isConfirmingClear = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .confirmationDialog(viewModel.clearTitle, isPresented: $isConfirmingClear, titleVisibility: .visible) {
                    Button(viewModel.clearTitle, role: .destructive) {
                        Motion.perform(reduceMotion) { viewModel.clear(in: context) }
                    }
                } message: {
                    Text(viewModel.clearMessage)
                }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: AskViewModel) -> some View {
        if !viewModel.hasPlan {
            ContentUnavailableView(viewModel.emptyTitle, systemImage: "bubble.left.and.text.bubble.right",
                                   description: Text(viewModel.emptyDetail))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.betweenCards) {
                        if viewModel.showsIntro {
                            AskIntroCard(viewModel: viewModel) { question in
                                send(question, viewModel)
                            }
                            .transition(.opacity)
                        }
                        ForEach(viewModel.rows) { row in
                            ChatBubble(row: row)
                                .id(row.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if isThinking {
                            ThinkingBubble(text: viewModel.thinkingText)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.lastRowID) { _, newID in
                    guard let newID else { return }
                    Motion.perform(reduceMotion) { proxy.scrollTo(newID, anchor: .bottom) }
                }
            }
            // the typing box sits on top of the tab bar like Messages
            .safeAreaInset(edge: .bottom) {
                AskInputBar(text: $draft, isTyping: $isTyping, prompt: viewModel.prompt,
                            sendLabel: viewModel.sendLabel, canSend: viewModel.canSend(draft) && !isThinking,
                            footnote: viewModel.footnote) {
                    send(draft, viewModel)
                }
            }
        }
    }

    // clears the box shows the question then the answer when it's ready
    private func send(_ text: String, _ viewModel: AskViewModel) {
        guard !isThinking else { return }
        draft = ""
        var question: String?
        Motion.perform(reduceMotion) {
            question = viewModel.saveQuestion(text, in: context)
            isThinking = question != nil
        }
        guard let question else { return }
        Task {
            let answer = await viewModel.findAnswer(to: question)
            Motion.perform(reduceMotion) {
                if let answer { viewModel.saveAnswer(answer, in: context) }
                isThinking = false
            }
        }
    }
}

// MARK: - Intro + suggestion chips (only while the chat is empty)

// intro and suggestions
struct AskIntroCard: View {
    let viewModel: AskViewModel
    let onAsk: (String) -> Void

    var body: some View {
        SectionCard(title: viewModel.introTitle, symbol: "text.bubble", collapsible: false, rememberAs: "ask.intro") {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.introDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // chips wrap onto new lines when they don't fit
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { chips }
                    VStack(alignment: .leading, spacing: 8) { chips }
                }
            }
            .padding(.vertical, Spacing.rowVertical)
        }
    }

    private var chips: some View {
        ForEach(viewModel.suggestions, id: \.self) { question in
            Button(question) { onAsk(question) }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .tint(Color.remedyTeal)
                .font(.subheadline.weight(.medium))
        }
    }
}

// MARK: - One bubble

// "Looking through your papers" while the answer is coming
struct ThinkingBubble: View {
    let text: String

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                ProgressView()
                Text(text)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .cardStyle()
            Spacer(minLength: 24)
        }
        .accessibilityElement(children: .combine)
    }
}

// one question or answer
struct ChatBubble: View {
    let row: ChatRow

    var body: some View {
        if row.isFromPatient {
            HStack {
                Spacer(minLength: 48)
                Text(row.text)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.remedyTeal))
            }
            .accessibilityLabel("You asked: \(row.text)")
        } else {
            HStack {
                answer
                Spacer(minLength: 24)
            }
        }
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if row.symbol.isEmpty {
                Text(row.text)
            } else {
                Label {
                    Text(row.text)
                } icon: {
                    Image(systemName: row.symbol)
                        .foregroundStyle(row.tone.color)
                }
            }

            if row.showsQuote {
                Divider()
                PaperQuoteCard(quote: row.quote, source: row.quoteSource)
            }

            if row.showsCall {
                // 911 = big red button
                CallButton(title: row.callTitle, phoneURL: row.callURL, prominent: row.tone == .stop)
                    .tint(row.tone == .stop ? Color.red : Color.remedyTeal)
            }
        }
        .font(.body)
        .padding(Spacing.insideCard)
        .cardStyle(row.tone == .neutral ? Color.cardBackground : row.tone.color.opacity(0.12))
        .controlSize(.large)
    }
}

// MARK: - Typing box

// typing box
struct AskInputBar: View {
    @Binding var text: String
    var isTyping: FocusState<Bool>.Binding
    let prompt: String
    let sendLabel: String
    let canSend: Bool
    let footnote: String
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(prompt, text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .focused(isTyping)
                    .submitLabel(.send)
                    .onSubmit { if canSend { onSend() } }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.cardBackground))

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.remedyTeal : Color.inactive)
                }
                .disabled(!canSend)
                .accessibilityLabel(sendLabel)
            }
            Text(footnote)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    AskView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    AskView()
}
