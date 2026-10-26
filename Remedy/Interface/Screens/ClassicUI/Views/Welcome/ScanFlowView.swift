//
//  ScanFlowView.swift
//  Remedy
//
//  welcome scan and confirm flow
//

import SwiftUI
import SwiftData

struct ScanFlowView: View {

    @State private var viewModel: ScanFlowViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isAddingPapers: Bool = false, planHasSurgeryDate: Bool = false) {
        _viewModel = State(initialValue: ScanFlowViewModel(isAddingPapers: isAddingPapers,
                                                           planHasSurgeryDate: planHasSurgeryDate))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .welcome: WelcomeView(viewModel: viewModel)
                case .choosePaper: ChoosePaperView(viewModel: viewModel)
                case .reading: ReadingView(viewModel: viewModel)
                case .confirm: ConfirmView(viewModel: viewModel)
                case .finish: FinishView(viewModel: viewModel) { dismiss() }
                }
            }
            .transition(.slideIn(reduceMotion: reduceMotion))
            .background(Color.screenBackground)
            .toolbar {
                if viewModel.isAddingPapers {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(viewModel.cancelButton) { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Reading (live steps then what was found and the cleaned page)

// progress while reading the papers
struct ReadingView: View {
    let viewModel: ScanFlowViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // is the full text open
    @State private var isShowingAll = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.betweenCards) {
                TopCard(title: viewModel.readingTitle) {
                    ReadingPageAnimation(isScanning: viewModel.pageIsScanning,
                                         isBlackedOut: viewModel.pageIsBlackedOut,
                                         badge: viewModel.stage.symbol,
                                         isDone: viewModel.isReadingDone)
                }

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.stages) { stage in
                            ReadingStageRow(stage: stage,
                                            isDone: viewModel.isDone(stage),
                                            isRunning: viewModel.isRunning(stage),
                                            detail: viewModel.detail(for: stage))
                        }
                    }
                }

                // a real clock so a long wait never looks stuck
                if !viewModel.isReadingDone {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(viewModel.waitText(now: context.date), systemImage: "hourglass")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .opacity(viewModel.waitText(now: context.date).isEmpty ? 0 : 1)
                            .animation(.easeInOut, value: viewModel.waitText(now: context.date))
                    }
                }

                // what was found counting up to the real numbers
                if viewModel.isReadingDone {
                    FoundCountsCard(viewModel: viewModel)
                        .task { await viewModel.countUp(reduceMotion: reduceMotion) }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }

                // what was actually sent the page with personal info blacked out
                if viewModel.isReadingDone {
                    SectionCard(title: viewModel.cleanedTitle, symbol: "eye.slash", detail: "",
                                tone: .good, collapsible: false, rememberAs: "scan.cleaned") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(viewModel.removedText, systemImage: "lock.shield.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Tone.good.color)
                            RedactedText(text: viewModel.cleanedText)
                                .font(.subheadline)
                                .lineLimit(6)
                            Button {
                                isShowingAll = true
                            } label: {
                                Label(viewModel.seeAllTitle, systemImage: "doc.text.magnifyingglass")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.vertical, Spacing.rowVertical)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    // anything the patient should double-check on the paper
                    ForEach(viewModel.warnings, id: \.self) { warning in
                        ToneBox(eyebrow: "Check this", title: warning, tone: .caution)
                    }
                    if !viewModel.readByText.isEmpty {
                        Text(viewModel.readByText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        viewModel.goToConfirm()
                    } label: {
                        Text(viewModel.continueButton)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $isShowingAll) {
            SentPagesView(viewModel: viewModel)
        }
    }
}

// one reading step with its moving icon and what really happened
struct ReadingStageRow: View {
    let stage: ReadingStage
    let isDone: Bool
    let isRunning: Bool
    let detail: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : stage.symbol)
                .font(.title3)
                .foregroundStyle(isDone ? Tone.good.color : isRunning ? Color.remedyTeal : Color.inactive)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: isRunning && !reduceMotion)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title)
                    .fontWeight(isRunning ? .semibold : .regular)
                    .foregroundStyle(isDone || isRunning ? .primary : .secondary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(isDone ? Tone.good.color : Color.secondary)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
            if isRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .animation(.snappy, value: detail)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : isRunning ? "Working" : "Waiting")
    }
}

// medicines rules visits and to-dos found ticking up
struct FoundCountsCard: View {
    let viewModel: ScanFlowViewModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.foundTitle)
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.foundCounts.enumerated()), id: \.element.id) { index, found in
                        VStack(spacing: 4) {
                            Image(systemName: found.symbol)
                                .font(.title3)
                                .foregroundStyle(found.tone.color)
                            Text("\(viewModel.shownCount(index))")
                                .font(.title.weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(found.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(found.total) \(found.title)")
                    }
                }
            }
        }
    }
}

// every page exactly as the ai got it
struct SentPagesView: View {
    let viewModel: ScanFlowViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    Label(viewModel.sentPagesDetail, systemImage: "lock.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.cleanedPages) { page in
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(page.title)
                                        .font(.headline)
                                    Spacer()
                                    Label(page.removedText, systemImage: "eye.slash")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Tone.good.color)
                                }
                                Divider()
                                if let picture = page.picture {
                                    Image(uiImage: picture)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                                    Text(viewModel.pictureCaption)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Divider()
                                }
                                RedactedText(text: page.text)
                                    .font(.callout)
                                    .lineSpacing(3)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.vertical, 8)
            }
            .background(Color.screenBackground)
            .navigationTitle(viewModel.sentPagesTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Finish (summary + surgery date)

// all done screen
struct FinishView: View {
    @Bindable var viewModel: ScanFlowViewModel
    let onDone: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.betweenCards) {
                TopCard(title: viewModel.finishTitle, subtitle: viewModel.finishDetail) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Tone.good.color)
                        .symbolEffect(.bounce, value: viewModel.step)
                }

                if viewModel.needsSurgeryDate {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(viewModel.surgeryDateTitle)
                                .font(.headline)
                            Text(viewModel.surgeryDateDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DatePicker(viewModel.surgeryDateTitle, selection: $viewModel.surgeryDate,
                                       displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                        }
                    }
                }

                Button {
                    viewModel.save(in: context)
                    onDone()        // a sheet closes; on first run the tabs appear by themselves
                } label: {
                    Text(viewModel.startButton)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .sensoryFeedback(.success, trigger: viewModel.step)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.scrollBottom)
        }
    }
}

#Preview("First run") {
    ScanFlowView()
        .modelContainer(for: RemedySchema.models, inMemory: true)
}
