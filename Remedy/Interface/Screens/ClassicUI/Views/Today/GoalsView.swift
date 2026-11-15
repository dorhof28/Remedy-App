//
//  GoalsView.swift
//  Remedy
//
//  screen 23 daily goals from the papers counted with one tap, plus the check-in
//

import SwiftUI
import SwiftData

// today's goals
struct GoalsView: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query private var checkIns: [CheckIn]

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only what is open
    @State private var isCheckingIn = false
    @State private var shownGoal: GoalTile?
    @State private var added = 0

    var body: some View {
        let today = TodayViewModel(plan: plans.first, now: AppClock.now())
        let saved = checkIns.first { $0.day == today.day }
        List {
            if !today.goalTiles.isEmpty {
                Section {
                    ForEach(today.goalTiles) { tile in
                        Button { shownGoal = tile } label: {
                            ListRow(symbol: tile.symbol, tone: tile.isComplete ? .good : .info, title: tile.title,
                                    subtitle: GoalsWords.detail(tile)) {
                                if tile.isComplete {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.toneGreen)
                                        .accessibilityLabel("Done")
                                } else {
                                    Button {
                                        Motion.perform(reduceMotion) { today.addOne(to: tile, in: context) }
                                        added += 1
                                    } label: {
                                        Text(GoalsWords.doneOne).padding(.vertical, 10)
                                    }
                                    .buttonStyle(CapsuleFillStyle(fill: .accentFill, text: .onAccent))
                                    .font(.title3.weight(.semibold))
                                    .frame(minHeight: Spacing.minTarget)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Take One Back", systemImage: "minus.circle", role: .destructive) {
                                today.removeOne(from: tile, in: context)
                            }
                        }
                        .accessibilityAction(named: "Take One Back") { today.removeOne(from: tile, in: context) }
                    }
                } footer: {
                    Text(GoalsWords.footer).font(.subheadline).foregroundStyle(Color.ink2)
                }
            }
            if today.showsCheckIn {
                Section {
                    Button { isCheckingIn = true } label: {
                        ListRow(symbol: "heart", title: GoalsWords.checkInTitle,
                                subtitle: GoalsWords.checkInDetail(saved), showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } header: {
                    ListSectionHeader(title: GoalsWords.checkInHeader)
                }
            }
            Section {
                NavigationLink { CheckInHistoryView() } label: {
                    ListRow(symbol: "chart.xyaxis.line", title: GoalsWords.historyTitle, subtitle: GoalsWords.historyDetail)
                }
            }
        }
        .remedyList()
        .navigationTitle(GoalsWords.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: added)
        .sheet(isPresented: $isCheckingIn) {
            CheckInView(viewModel: CheckInViewModel(plan: plans.first, now: AppClock.now()))
        }
        .sheet(item: $shownGoal) { tile in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if tile.goal.quote.isEmpty {
                            Text(GoalsWords.noQuote).font(.body).foregroundStyle(Color.ink2)
                        } else {
                            PaperQuote(source: "From your paper", quote: "\u{201C}\(tile.goal.quote)\u{201D}",
                                       plain: PaperAbbreviations.explain(tile.goal.quote))
                        }
                    }
                    .padding(Spacing.screenEdge)
                }
                .background(Color.screenBackground)
                .navigationTitle(tile.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { shownGoal = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
