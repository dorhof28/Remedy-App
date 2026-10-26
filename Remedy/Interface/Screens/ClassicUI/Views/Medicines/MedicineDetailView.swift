//
//  MedicineDetailView.swift
//  Remedy
//
//  classic one medicine
//

import SwiftUI
import SwiftData

struct MedicineDetailView: View {
    let medicine: MedicineInstruction

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isConfirmingLog = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
            ScrollView {
                VStack(spacing: Spacing.betweenCards) {
                    topCard(viewModel)

                    if viewModel.showsStatBoxes { statBoxes(viewModel) }
                    if viewModel.showsTimer { timerCard(viewModel) }
                    if viewModel.showsStatusBox {
                        ToneBox(eyebrow: viewModel.statusBox.eyebrow, title: viewModel.statusBox.title,
                                tone: viewModel.statusBox.tone)
                    }

                    if viewModel.showsTodayDoses {
                        SectionCard(title: viewModel.todayTitle, symbol: "sun.max",
                                    detail: viewModel.todayDosesSummary, rememberAs: "medicine.today") {
                            dosesList(viewModel)
                        }
                    }

                    if viewModel.showsHowTo {
                        SectionCard(title: viewModel.howToTitle, symbol: "pills", rememberAs: "medicine.howto") {
                            InfoRows(rows: viewModel.howToRows)
                        }
                    }

                    if viewModel.showsCovers {
                        SectionCard(title: viewModel.includesTitle, symbol: "list.bullet", rememberAs: "medicine.covers") {
                            Text(viewModel.coversText)
                                .font(.subheadline)
                                .padding(.vertical, Spacing.rowVertical)
                        }
                    }

                    if viewModel.showsException {
                        SectionCard(title: viewModel.smallPrintTitle, symbol: "exclamationmark.bubble",
                                    tone: .caution, rememberAs: "medicine.smallprint") {
                            Text(viewModel.exceptionText)
                                .font(.subheadline)
                                .padding(.vertical, Spacing.rowVertical)
                        }
                    }

                    if viewModel.showsRelated {
                        SectionCard(title: viewModel.relatedTitle, symbol: "arrow.left.arrow.right",
                                    rememberAs: "medicine.related") {
                            relatedList(viewModel)
                            CardFootnote(text: viewModel.relatedFooter)
                        }
                    }

                    SectionCard(title: viewModel.paperTitle, symbol: "doc.text", rememberAs: "medicine.paper") {
                        PaperQuoteCard(quote: viewModel.quote, source: viewModel.quoteSource)
                            .padding(.vertical, Spacing.rowVertical)
                    }

                    if viewModel.showsHistory {
                        SectionCard(title: viewModel.historyTitle, symbol: "clock.arrow.circlepath",
                                    startsExpanded: false, rememberAs: "medicine.history") {
                            InfoRows(rows: viewModel.historyRows)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.scrollBottom)
            }
            .background(Color.screenBackground)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(viewModel.logConfirmationTitle, isPresented: $isConfirmingLog, titleVisibility: .visible) {
                Button(viewModel.logConfirmButton) {
                    Motion.perform(reduceMotion) { viewModel.logAsNeeded(in: context) }
                }
            } message: {
                Text(viewModel.logConfirmationMessage)
            }
        }
    }

    private func topCard(_ viewModel: MedicineDetailViewModel) -> some View {
        TopCard(title: viewModel.title, subtitle: viewModel.subtitle) {
            MedicineIcon(pillShape: viewModel.pillShape, pillColor: viewModel.pillColor,
                         symbol: viewModel.topSymbol, tone: viewModel.topTone, size: 72)
        }
    }

    private func statBoxes(_ viewModel: MedicineDetailViewModel) -> some View {
        HStack(spacing: 14) {
            ForEach(viewModel.statBoxes) { box in
                StatTile(title: box.title, value: box.value, caption: box.caption, progress: box.progress)
            }
        }
        .fixedSize(horizontal: false, vertical: true)     // both boxes the same height
    }

    private func timerCard(_ viewModel: MedicineDetailViewModel) -> some View {
        let timer = viewModel.timer
        return VStack(spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: timer.progress, lineWidth: 7, tone: timer.isAllowedNow ? .good : .info)
                    Image(systemName: timer.isAllowedNow ? "checkmark" : "hourglass")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(timer.isAllowedNow ? Tone.good.color : Tone.info.color)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(timer.label)
                        .textCase(.uppercase)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(timer.value)
                        .font(.title.bold())
                        .contentTransition(.numericText())
                    Text(timer.caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            Button {
                isConfirmingLog = true
            } label: {
                Label(viewModel.logButtonTitle, systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!timer.isAllowedNow)
        }
        .padding(Spacing.insideCard)
        .cardStyle()
    }

    private func dosesList(_ viewModel: MedicineDetailViewModel) -> some View {
        DividedList(items: viewModel.todayDoses, inset: 40) { row in
            Button {
                Motion.perform(reduceMotion) { viewModel.toggle(row, in: context) }
            } label: {
                HStack(spacing: 12) {
                    CheckCircle(state: row.state)
                    Text(row.timeText)
                    Spacer()
                    Text(row.stateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(row.tone.color)
                }
                .padding(.vertical, Spacing.rowVertical)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.spokenLabel)
            .accessibilityHint(row.spokenHint)
        }
    }

    private func relatedList(_ viewModel: MedicineDetailViewModel) -> some View {
        DividedList(items: viewModel.related, inset: 42) { row in
            NavigationLink(value: row.medicine) {
                IconRow(symbol: row.symbol, tone: row.tone, title: row.title,
                        subtitle: row.subtitle, showsChevron: true)
            }
            .buttonStyle(.plain)
        }
    }
}
