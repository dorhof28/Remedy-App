//
//  TodayAfterView.swift
//  Remedy
//
//  today after surgery
//

import SwiftUI
import SwiftData

struct TodayAfterView: View {
    let viewModel: TodayViewModel
    let showUndo: (TodayUndo?) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsDoseList = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.betweenCards) {
                TodayHeader(symbol: viewModel.headerSymbol,
                            title: viewModel.headerTitle,
                            detail: viewModel.headerDetail)

                NowDoseCardView(
                    card: viewModel.nowCard,
                    takeTitle: viewModel.takeButtonTitle,
                    skipTitle: viewModel.skipButtonTitle,
                    progress: viewModel.showsDoseProgress ? viewModel.doseProgress : nil,
                    onTake: { act { viewModel.takeNow(in: context) } },
                    onSkip: { act { viewModel.skipNow(in: context) } },
                    onOpenList: { showsDoseList = true }
                )

                if viewModel.showsAsNeeded {
                    AsNeededCard(title: viewModel.asNeededTitle, rows: viewModel.asNeededRows) { row in
                        act { viewModel.takeAsNeeded(row, in: context) }
                    }
                }

                if viewModel.showsGoals {
                    GoalsCard(title: viewModel.goalsTitle,
                              hint: viewModel.goalsHint,
                              tiles: viewModel.goalTiles,
                              onAdd: { tile in Motion.perform(reduceMotion) { viewModel.addOne(to: tile, in: context) } },
                              onRemove: { tile in Motion.perform(reduceMotion) { viewModel.removeOne(from: tile, in: context) } })
                }

                if viewModel.showsTasks {
                    TaskListCard(title: viewModel.tasksTitle, rows: viewModel.taskRows) { row in
                        act { viewModel.toggle(row, in: context) }
                    }
                }

                if viewModel.showsNotYet {
                    RowListCard(title: viewModel.notYetTitle, rows: viewModel.notYetRows)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.betweenCards)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $showsDoseList) {
            DoseListSheet(title: viewModel.doseListTitle, sections: viewModel.doseSections) { row in
                act { viewModel.toggle(row, in: context) }
            }
        }
    }

    private func act(_ change: () -> TodayUndo?) {
        Motion.perform(reduceMotion) {
            showUndo(change())
        }
    }
}

// the dose to take now
struct NowDoseCardView: View {
    let card: NowDoseCard
    let takeTitle: String
    let skipTitle: String
    let progress: DoseProgress?
    let onTake: () -> Void
    let onSkip: () -> Void
    let onOpenList: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                // what and when
                VStack(alignment: .leading, spacing: 10) {
                    CardEyebrow(text: card.eyebrow, symbol: card.symbol, tone: card.tone)

                    Text(card.title)
                        .font(.title2.bold())

                    ForEach(card.lines) { line in
                        HStack(spacing: 12) {
                            MedicineIcon(pillShape: line.pillShape, pillColor: line.pillColor,
                                         symbol: "pills.fill", tone: card.tone, size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.name).font(.body.weight(.medium))
                                if !line.how.isEmpty {
                                    Text(line.how).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !card.detail.isEmpty {
                        Text(card.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(card.spokenLabel)
                .id(card.eyebrow + card.title)
                .transition(.push(from: .trailing))

                if card.showsButtons {
                    HStack(spacing: 12) {
                        Button(action: onTake) {
                            Label(takeTitle, systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onSkip) {
                            Text(skipTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: 120)
                    }
                    .controlSize(.large)
                }

                if let progress {
                    Divider()
                    Button(action: onOpenList) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(progress.text)
                                        .font(.subheadline.weight(.medium))
                                        .contentTransition(.numericText())
                                    if !progress.detail.isEmpty {
                                        ToneBadge(text: progress.detail, tone: .stop)
                                    }
                                }
                                SegmentBar(total: progress.total, filled: progress.taken, tone: progress.tone)
                            }
                            Chevron()
                        }
                        .contentShape(Rectangle())
                        .frame(minHeight: Spacing.minTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(progress.spokenLabel)
                    .accessibilityHint(progress.spokenHint)
                }
            }
        }
    }
}

// only when needed medicines
struct AsNeededCard: View {
    let title: String
    let rows: [AsNeededRow]
    let onTake: (AsNeededRow) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.name).font(.body.weight(.medium))
                            Text(row.status)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(row.tone.color)
                            if !row.detail.isEmpty {
                                Text(row.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(row.spokenLabel)
                        Spacer(minLength: 0)
                        Button(row.buttonTitle) { onTake(row) }
                            .buttonStyle(.bordered)
                            .disabled(!row.canTake)
                    }
                }
            }
        }
    }
}

// daily goals
struct GoalsCard: View {
    let title: String
    let hint: String
    let tiles: [GoalTile]
    let onAdd: (GoalTile) -> Void
    let onRemove: (GoalTile) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(tiles) { tile in
                        Button {
                            onAdd(tile)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: tile.symbol)
                                        .foregroundStyle(tile.tone.color)
                                    Spacer()
                                    Text(tile.countText)
                                        .font(.subheadline.weight(.semibold))
                                        .contentTransition(.numericText())
                                }
                                Text(tile.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                SegmentBar(total: tile.target, filled: tile.count, tone: tile.tone)
                            }
                            .padding(12)
                            .background(Color.tileBackground, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Take one back", systemImage: "minus.circle", role: .destructive) {
                                onRemove(tile)
                            }
                        }
                        .sensoryFeedback(.increase, trigger: tile.count)
                        .accessibilityLabel(tile.spokenLabel)
                        .accessibilityHint("Double-tap to add one.")
                    }
                }
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HealthStepsLine()       // steps from Apple Health, if turned on in Settings
            }
        }
    }
}

// every dose today
struct DoseListSheet: View {
    let title: String
    let sections: [DoseSection]
    let onToggle: (DoseListRow) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            Button {
                                onToggle(row)
                            } label: {
                                HStack(spacing: 12) {
                                    CheckCircle(state: row.state)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.name)
                                        if !row.how.isEmpty {
                                            Text(row.how).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(row.timeText).font(.subheadline.weight(.medium))
                                        Text(row.stateText).font(.caption).foregroundStyle(row.tone.color)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(row.spokenLabel)
                            .accessibilityHint(row.spokenHint)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
