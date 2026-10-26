//
//  TodayBeforeView.swift
//  Remedy
//
//  today before surgery
//

import SwiftUI
import SwiftData

struct TodayBeforeView: View {
    let viewModel: TodayViewModel
    let showUndo: (TodayUndo?) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.betweenCards) {
                TodayHeader(symbol: viewModel.headerSymbol,
                            title: viewModel.headerTitle,
                            detail: viewModel.headerDetail)

                BeforeTopCardView(card: viewModel.beforeTopCard) {
                    Motion.perform(reduceMotion) {
                        showUndo(viewModel.putAwayStopsToday(in: context))
                    }
                }

                if viewModel.showsOnHold {
                    RowListCard(title: viewModel.onHoldTitle,
                                rows: viewModel.onHoldVisibleRows,
                                footer: viewModel.onHoldMoreText)
                }

                if viewModel.showsComingUp {
                    RowListCard(title: viewModel.comingUpTitle, rows: viewModel.comingUpRows)
                }

                if viewModel.showsOkToTake {
                    RowListCard(title: viewModel.okToTakeTitle, rows: viewModel.okToTakeRows)
                }

                if viewModel.showsTasks {
                    TaskListCard(title: viewModel.tasksTitle, rows: viewModel.taskRows) { row in
                        Motion.perform(reduceMotion) {
                            showUndo(viewModel.toggle(row, in: context))
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.betweenCards)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// what to stop today
struct BeforeTopCardView: View {
    let card: BeforeTopCard
    let onDone: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardEyebrow(text: card.eyebrow, symbol: card.symbol, tone: card.tone)

                Text(card.title)
                    .font(.title2.bold())

                if !card.names.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(card.names, id: \.self) { name in
                            Label(name, systemImage: card.nameSymbol)
                                .font(.body.weight(.medium))
                        }
                    }
                }

                if !card.detail.isEmpty {
                    Text(card.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if card.isDone {
                    Label(card.doneText, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Tone.good.color)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if let buttonTitle = card.buttonTitle {
                    Button(action: onDone) {
                        Text(buttonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(card.tone.color)
                    .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(card.spokenLabel)
        .sensoryFeedback(.success, trigger: card.isDone) { _, isDone in isDone }
    }
}
