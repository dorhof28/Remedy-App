//
//  PlanPages.swift
//  Remedy
//
//  classic pages pushed from the plan: whole journey, instructions, surgery day, check-ins, papers
//

import SwiftUI
import SwiftData

// the pages the plan tab opens
struct PlanPageView: View {
    let page: PlanPage
    // shows a day on the plan's calendar after going back
    var onPickDay: (Int) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    // redraws the notes when the office's answer is saved
    @Query private var checkNotes: [PaperCheckNote]

    var body: some View {
        let viewModel = PlanViewModel(plan: plans.first, now: AppClock.now())
        switch page {
        case .whatChanged:
            WhatChangedPage()
        case .papers:
            PapersView()
        case .instructions:
            InstructionsView()
        case .checkIns:
            CheckInHistoryView()
        case .firstWeek:
            PreviewWeekView(plan: viewModel.plan)
        default:
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    content(viewModel)
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, 4)
                .padding(.bottom, Spacing.scrollBottom)
            }
            .remedyBackground()
            .navigationTitle(viewModel.title(of: page))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: PlanViewModel) -> some View {
        switch page {
        case .journey:
            JourneyTimeline(rows: viewModel.overviewRows) { day in
                dismiss()
                onPickDay(day)
            }
        case .surgeryDay:
            if let plan = viewModel.plan {
                HospitalDayFields(plan: plan)
                    .padding(Spacing.insideCard)
                    .cardStyle()
            }
        case .paperNotes:
            ForEach(PaperCheckViewModel(plan: viewModel.plan, now: viewModel.now).blueNotes) { PaperCheckNoteCard(card: $0) }
        case .whatChanged, .instructions, .checkIns, .firstWeek, .papers:
            EmptyView()
        }
    }

    // every paper with who and when, then what the newest one changed
    @ViewBuilder
    private func papers(_ viewModel: PlanViewModel) -> some View {
        let list = PapersSettingsViewModel(plan: viewModel.plan)
        let check = PaperCheckViewModel(plan: viewModel.plan, now: viewModel.now)
        let red = check.redCards
        let notes = check.blueNotes
        // paper notes first: disagreements never hidden, then the calm notes
        if !red.isEmpty || !notes.isEmpty {
            ListHeader(title: viewModel.title(of: .paperNotes), trailing: "\(red.count + notes.count)", symbol: "note.text", tone: red.isEmpty ? .info : .caution)
            ForEach(red) { PaperCheckCard(card: $0) }
            ForEach(notes) { PaperCheckNoteCard(card: $0) }
        }
        if list.papers.isEmpty {
            ContentUnavailableView(list.emptyTitle, systemImage: ItemKind.paper.symbol)
        } else {
            ListHeader(title: viewModel.papersListTitle, trailing: "\(list.papers.count)", symbol: "doc.text", tone: .info)
            GroupedCard {
                ForEach(list.papers) { paper in
                    ItemRow(kind: .paper, title: list.rowTitle(paper), detail: list.rowDetail(paper))
                        .accessibilityElement(children: .combine)
                }
            }
        }
        if WhatChangedViewModel(plan: viewModel.plan) != nil {
            GroupedCard {
                NavigationLink(value: PlanPage.whatChanged) {
                    ItemRow(kind: .custom(symbol: "arrow.triangle.2.circlepath", tone: .info),
                            title: WhatChangedViewModel.planRowTitle) { Chevron() }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
