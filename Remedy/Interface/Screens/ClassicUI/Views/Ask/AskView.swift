//
//  AskView.swift
//  Remedy
//
//  classic ask tab chat
//

import SwiftUI
import SwiftData

// classic ask tab
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
                .remedyBackground()
                .navigationTitle(viewModel.title)
                .navigationBarTitleDisplayMode(.large)
                .helpButtons(showsSettings: false, clearChat: viewModel.canClear ? { isConfirmingClear = true } : nil)
                .confirmationDialog(AskViewModel.clearChatTitle, isPresented: $isConfirmingClear, titleVisibility: .visible) {
                    Button(AskViewModel.clearChatTitle, role: .destructive) {
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
            HeroScreen(symbol: "questionmark.bubble", title: viewModel.emptyTitle, text: viewModel.emptyDetail) { EmptyView() }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                        DisclaimerBox()
                        if viewModel.showsIntro {
                            HeroMessage(symbol: "questionmark.bubble", title: AskViewModel.heroTitle, text: AskViewModel.heroText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)
                            AskExamples(viewModel: viewModel) { send($0, viewModel) }
                                .transition(.opacity)
                        }
                        ForEach(viewModel.rows) { row in
                            ChatBubble(row: row, question: viewModel.question(before: row), surgeonURL: viewModel.surgeonURL) {
                                send($0, viewModel)
                            }
                            .id(row.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if isThinking {
                            ThinkingBubble(text: viewModel.thinkingText)
                                .transition(.opacity)
                        }
                        // the end of the chat, so the newest line is never under the typing box
                        Color.clear.frame(height: 1).id("chat-end")
                    }
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(viewModel.showsIntro ? .top : .bottom)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.lastRowID) { _, _ in
                    Motion.perform(reduceMotion) { proxy.scrollTo("chat-end", anchor: .bottom) }
                }
                .onChange(of: isThinking) { _, _ in
                    Motion.perform(reduceMotion) { proxy.scrollTo("chat-end", anchor: .bottom) }
                }
                .onChange(of: isTyping) { _, typing in
                    guard typing else { return }
                    Motion.perform(reduceMotion) { proxy.scrollTo("chat-end", anchor: .bottom) }
                }
            }
            // the typing box sits on top of the tab bar like Messages
            .safeAreaInset(edge: .bottom, spacing: 0) {
                askBar(viewModel)
            }
        }
    }

    private func askBar(_ viewModel: AskViewModel) -> some View {
        AskInputBar(text: $draft, isTyping: $isTyping, prompt: viewModel.prompt,
                    sendLabel: viewModel.sendLabel, canSend: viewModel.canSend(draft) && !isThinking) {
            send(draft, viewModel)
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

// MARK: - Invitation and examples (only while the chat is empty)

// example questions that wrap onto more lines, never a sideways strip
struct AskExamples: View {
    let viewModel: AskViewModel
    let onAsk: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(viewModel.examples, id: \.self) { question in
                Button { onAsk(question) } label: {
                    Text(question)
                        .font(.body)
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: Spacing.minTarget)
                        .background(Capsule().fill(Color.cardBackground))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AskViewModel.examplesTitle)
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
                    .foregroundStyle(Color.ink2)
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
    var question: String = ""
    var surgeonURL: URL? = nil
    // asks again with the medicine they tapped
    let onChoose: (String) -> Void

    var body: some View {
        if row.isFromPatient {
            HStack {
                Spacer(minLength: 48)
                Text(row.text)
                    .font(.body)
                    .foregroundStyle(Color.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.accentFill))
            }
            .accessibilityLabel("You asked: \(row.text)")
        } else if row.tone == .stop {
            emergency
        } else {
            answer
                .contextMenu {
                    Button(AskViewModel.readAloudTitle, systemImage: "speaker.wave.2") { Speaker.toggle(row.text) }
                }
        }
    }

    // a warning sign: 911 first, the question never reached the AI
    private var emergency: some View {
        VStack(alignment: .leading, spacing: 10) {
            ActionCard(style: .stop, eyebrow: AskViewModel.emergencyEyebrow, eyebrowSymbol: "exclamationmark.triangle",
                       title: AskViewModel.emergencyHeading, text: AskViewModel.emergencyText(question: question)) {
                VStack(spacing: 10) {
                    EmergencyCallButton()
                    if let surgeonURL {
                        PhoneButton(title: AskViewModel.callSurgeonTitle, url: surgeonURL)
                    }
                }
            }
            Text(AskViewModel.notSentFootnote)
                .font(.footnote)
                .foregroundStyle(Color.ink2)
                .padding(.horizontal, 4)
        }
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(row.text)
                .font(.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if row.showsQuote {
                PaperQuote(source: AskViewModel.pageSource(row.quoteSource), quote: "\u{201C}\(row.quote)\u{201D}")
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.screenBackground))
            }
            ForEach(row.choices, id: \.self) { name in
                SecondaryButton(title: name) { onChoose(name) }
            }
            if row.showsCall, let url = row.callURL {
                PhoneButton(title: AskViewModel.callOfficeTitle, url: url)
            }
        }
        .padding(Spacing.insideCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
        .padding(.trailing, 24)
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
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                TextField(prompt, text: $text, axis: .vertical)
                    // plain so it is part of the glass bar, not a box inside it
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused(isTyping)
                    .submitLabel(.send)
                    .textInputAutocapitalization(.sentences)
                    .padding(.leading, 12)
                    .onSubmit { if canSend { onSend() } }
                    // a growing box can add a line break on Return, that means send
                    .onChange(of: text) { _, new in
                        let result = EditText.submitted(new)
                        guard result.didSubmit else { return }
                        text = result.text
                        if canSend { onSend() }
                    }

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(canSend ? Color.onAccent : Color.ink3)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(canSend ? Color.accentFill : Color.surface2))
                        .frame(width: Spacing.tapMin, height: Spacing.tapMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel(sendLabel)
            }
            .padding(.horizontal, 6)
            .frame(minHeight: 56)
            .glassStyle(cornerRadius: 28)
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.vertical, 8)
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    AskView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    AskView()
}
