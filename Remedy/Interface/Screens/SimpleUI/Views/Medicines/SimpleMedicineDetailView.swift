//
//  SimpleMedicineDetailView.swift
//  Remedy
//
//  simple one medicine (82): the answer in a tinted card, one big button, then the paper
//

import SwiftUI
import SwiftData

// simple medicine page
struct SimpleMedicineDetailView: View {
    let medicine: MedicineInstruction

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingLog = false
    @State private var isLoggingEarlier = false
    @State private var isShowingPaper = false
    // UI only the medicine is being deleted so nothing reads it any more
    @State private var isRemoved = false
    // redraws the cards when the office's answer is saved
    @Query private var checkNotes: [PaperCheckNote]

    var body: some View {
        if isRemoved {
            RemedyBackground()
        } else {
            content
        }
    }

    private var content: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
            let check = PaperCheckViewModel(plan: medicine.plan, now: viewModel.now)
            let red = check.redCards(for: medicine)
            SimpleScreen(title: viewModel.headerName) {
                let subtitle = SimpleMedicineWords.subtitle(medicine, fallback: viewModel.paperNameLine)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                        .padding(.top, -6)
                }

                // papers disagree comes first, phrased as the thing to do
                if !red.isEmpty { SimpleDisagreementCard(cards: red) }

                verdictCard(viewModel)

                ForEach(check.blueNotes(for: medicine)) { PaperCheckNoteCard(card: $0, simple: true) }

                if viewModel.showsAsNeeded {
                    if viewModel.canLogAsNeeded {
                        Button { isConfirmingLog = true } label: {
                            Label(SimpleMedicineWords.tookOne, systemImage: "checkmark")
                        }
                        .buttonStyle(SimpleButtonStyle())
                    }
                }

                Button(SimpleMedicineWords.showPaper) { isShowingPaper = true }
                    .buttonStyle(SimpleButtonStyle(kind: .gray))

            }
            .fullScreenCover(isPresented: $isShowingPaper) {
                SourceQuoteSheet(data: viewModel.sourceQuote, report: viewModel.mistakeReport,
                                 title: viewModel.quoteSheetTitle, large: true)
            }
            .sheet(isPresented: $isLoggingEarlier) {
                EarlierDoseSheet(viewModel: viewModel, large: true)
            }
            .confirmationDialog(viewModel.logConfirmationTitle, isPresented: $isConfirmingLog, titleVisibility: .visible) {
                Button(viewModel.logConfirmButton) {
                    Motion.perform(reduceMotion) { viewModel.logAsNeeded(in: context) }
                }
            } message: {
                Text(viewModel.logConfirmationMessage)
            }
        }
    }

    // the answer in a tinted card with a big check row for each of today's doses
    private func verdictCard(_ viewModel: MedicineDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let canTake = viewModel.showsAsNeeded && viewModel.canLogAsNeeded
            let eyebrow = SimpleMedicineWords.eyebrow(medicine, canTake: canTake, fallback: viewModel.verdictEyebrow)
            let symbol = canTake ? "checkmark.circle" : viewModel.verdictEyebrowSymbol
            VStack(alignment: .leading, spacing: 6) {
                if !eyebrow.isEmpty {
                    Group {
                        if symbol.isEmpty {
                            Text(eyebrow)
                        } else {
                            Label(eyebrow, systemImage: symbol)
                        }
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.verdictCardTone == .neutral ? Color.ink2 : viewModel.verdictCardTone.color)
                }
                ForEach(SimpleMedicineWords.lines(medicine, canTake: canTake,
                                                  title: SimpleWording.plain(viewModel.verdictTitle),
                                                  detail: SimpleWording.plain(viewModel.verdictDetail)), id: \.self) { line in
                    Text(line)
                        .font(.title3)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            ForEach(viewModel.doseChips) { chip in
                Button {
                    Motion.perform(reduceMotion) { viewModel.toggle(chip.row, in: context) }
                } label: {
                    HStack(spacing: 14) {
                        RadioMark(isOn: chip.isTaken, size: 34)
                        Text(chip.text)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Spacing.tapSimple)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chip.row.spokenLabel)
                .accessibilityHint(chip.row.spokenHint)
            }
            .sensoryFeedback(.success, trigger: viewModel.todayTakenCount) { old, new in new > old }
        }
        .simpleOutlineCard(isNext: false, tone: viewModel.verdictCardTone)
    }

    // what read aloud says for this medicine
    private func spoken(_ viewModel: MedicineDetailViewModel) -> String {
        var parts = [viewModel.paperNameLine, viewModel.verdictSpokenCard]
        if viewModel.hasPaperQuote { parts.append("\(viewModel.simplePaperSays): \(viewModel.medicine.quote)") }
        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

