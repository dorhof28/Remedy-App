//
//  SimpleMedicineDetailView.swift
//  Remedy
//
//  simple one medicine
//

import SwiftUI
import SwiftData

struct SimpleMedicineDetailView: View {
    let medicine: MedicineInstruction

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isConfirmingLog = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
            SimpleScreen(title: viewModel.title) {
                // the answer first and biggest
                HStack(alignment: .top, spacing: 14) {
                    MedicineIcon(pillShape: viewModel.pillShape, pillColor: viewModel.pillColor,
                                 symbol: viewModel.topSymbol, tone: viewModel.topTone, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.verdictHeadline)
                            .font(.title2.bold())
                            .foregroundStyle(viewModel.verdictTone.color)
                        Text(viewModel.verdictSentence)
                            .font(.title3)
                            .lineLimit(5)
                            .minimumScaleFactor(0.85)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(viewModel.verdictTone.color.opacity(0.12))
                .accessibilityElement(children: .combine)

                if viewModel.showsAsNeeded {
                    Text(viewModel.asNeededStatusText)
                        .font(.title3.bold())
                        .foregroundStyle(viewModel.asNeededTone.color)
                    Button {
                        isConfirmingLog = true
                    } label: {
                        Label(viewModel.logButtonTitle, systemImage: "checkmark")
                    }
                    .buttonStyle(SimpleButtonStyle())
                    .disabled(!viewModel.canLogAsNeeded)
                }

                // today's times as big buttons side by side
                if viewModel.showsTodayDoses {
                    Text(viewModel.todayDosesSummary)
                        .font(.title3.bold())
                    HStack(spacing: 10) {
                        ForEach(viewModel.todayDoses.prefix(3)) { row in
                            Button {
                                Motion.perform(reduceMotion) { viewModel.toggle(row, in: context) }
                            } label: {
                                VStack(spacing: 6) {
                                    CheckCircle(state: row.state, size: 34)
                                    Text(row.timeText)
                                        .font(.headline)
                                    Text(row.stateText)
                                        .font(.subheadline)
                                        .foregroundStyle(row.tone.color)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity, minHeight: 110)
                                .cardStyle()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(row.spokenLabel)
                            .accessibilityHint(row.spokenHint)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    NavigationLink {
                        SimpleMedicineMoreView(medicine: medicine)
                    } label: {
                        Label("More about it", systemImage: "info.circle")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain, height: 60))
                    ReadAloudButton(title: "Read to me", text: viewModel.verdictSpoken)
                }
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
}

// MARK: - More about it (facts + the line from the papers)

// the rest of the medicine info
struct SimpleMedicineMoreView: View {
    let medicine: MedicineInstruction

    var body: some View {
        let viewModel = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
        SimpleScreen(title: viewModel.title) {
            Card {
                PaperQuoteCard(quote: viewModel.quote, source: viewModel.quoteSource)
            }
            SimplePagedList(items: viewModel.howToRows, perPage: 3) { row in
                SimpleFactCard(row: row)
            }
        }
    }
}
