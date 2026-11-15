//
//  SimpleAgendaView.swift
//  Remedy
//
//  simple my day for any day but today: everything planned on that day, and adding to the plan
//

import SwiftUI
import SwiftData

// the full list of one day, used inside my day for days other than today
struct SimpleOtherDayView: View {

    let day: Int

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only the add question and the thing being added
    @State private var isChoosing = false
    @State private var editing: PlanEditTarget?
    @State private var pendingAdd: PlanEditTarget?
    @State private var pendingPaper = false
    @State private var isAddingPaper = false

    var body: some View {
        let viewModel = PlanViewModel(plan: plans.first, now: AppClock.now())
        Group {
            detail(viewModel, picked: day)
            if viewModel.hasPlan {
                Button {
                    isChoosing = true
                } label: {
                    Label(PlanAddChoice.rowTitle, systemImage: "plus")
                }
                .buttonStyle(SimpleButtonStyle(kind: .gray))
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $isChoosing, onDismiss: {
            // open the editor once the choice sheet is gone
            if let next = pendingAdd { editing = next; pendingAdd = nil }
            if pendingPaper { isAddingPaper = true; pendingPaper = false }
        }) {
            // 98, the same three choices as Classic
            ChoiceSheet(title: PlanAddChoice.heading,
                        options: PlanAddChoice.sheetOptions.map { ChoiceOption(id: $0.id, symbol: $0.symbol, title: $0.title, detail: $0.detail) }) { id in
                if id == PlanAddSheet.paperID { pendingPaper = true } else { pendingAdd = PlanAddChoice.target(for: id) }
                isChoosing = false
            }
        }
        .sheet(isPresented: $isAddingPaper) {
            ScanFlowView(isAddingPapers: true, planHasSurgeryDate: plans.first?.surgeryDate != nil)
        }
        .sheet(item: $editing) { target in
            if let plan = plans.first { SimplePlanEditor(target: target, plan: plan) }
        }
    }

    // MARK: - Picked day

    @ViewBuilder
    private func detail(_ viewModel: PlanViewModel, picked: Int) -> some View {
        let rows = viewModel.dayRows(onDay: picked, checkedIn: checkIns.contains { $0.day == viewModel.day })
        // papers that disagree show on the days they affect, never hidden
        ForEach(viewModel.disagreementCards(onDay: picked)) { card in
            SimplePaperCheckCard(card: card, compact: true)
        }
        let progress = viewModel.dayProgressText(picked)
        if !progress.isEmpty {
            SimpleSectionTitle(title: progress, tone: .good, symbol: "checklist")
        }
        if rows.isEmpty {
            Text(viewModel.emptyDayText(picked))
                .font(.title3)
                .foregroundStyle(Color.ink2)
        }
        ForEach(rows) { row in
            self.row(row, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func row(_ row: PlanDayRow, viewModel: PlanViewModel) -> some View {
        let big = SimplePlanRow(kind: row.kind, title: row.title, detail: row.detail, detailTone: row.detailTone,
                                dimmed: row.isDone && row.trailing != .chevron) {
            switch row.trailing {
            case .none: EmptyView()
            case .chevron: Chevron()
            case .check(let done): TaskCheckMark(isDone: done, large: true)
            }
        }
        switch row.opens {
        case .task(let task):
            Button {
                Motion.perform(reduceMotion) { viewModel.toggle(task, in: context) }
            } label: { big }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: row.isDone) { _, isDone in isDone }
                .accessibilityLabel(SimpleWording.plain(row.spokenLabel))
                .accessibilityHint(row.isDone ? "Double-tap to mark as not done." : "Double-tap to mark as done.")
        case .medicine(let medicine):
            NavigationLink(value: medicine) { big }.buttonStyle(.plain)
        case .visit(let visit):
            NavigationLink(value: visit) { big }.buttonStyle(.plain)
        case .instructions:
            NavigationLink { SimplePlanRulesView() } label: { big }.buttonStyle(.plain)
        case .checkIn:
            NavigationLink { SimpleCheckInView(viewModel: CheckInViewModel(plan: plans.first, now: AppClock.now())) } label: { big }.buttonStyle(.plain)
        case .none:
            big
        }
    }
}
