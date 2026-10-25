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

// MARK: - Reading (3-step checklist, then the cleaned page)

// progress while reading the papers
struct ReadingView: View {
    let viewModel: ScanFlowViewModel

    // is the full text open
    @State private var isShowingAll = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.betweenCards) {
                TopCard(title: viewModel.readingTitle) {
                    IconTile(symbol: "doc.text.magnifyingglass", tone: .info, size: 72)
                }

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.stages) { stage in
                            HStack(spacing: 12) {
                                ZStack {
                                    if viewModel.isDone(stage) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Tone.good.color)
                                            .transition(.scale.combined(with: .opacity))
                                    } else if viewModel.isRunning(stage) {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(Color.inactive)
                                    }
                                }
                                .font(.title3)
                                .frame(width: 28)
                                Text(stage.title)
                                    .foregroundStyle(viewModel.isDone(stage) || viewModel.isRunning(stage) ? .primary : .secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
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
                    .buttonStyle(.borderedProminent)
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
                .buttonStyle(.borderedProminent)
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
