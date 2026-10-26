//
//  TodayView.swift
//  Remedy
//
//  classic today tab picks before or after view
//

import SwiftUI
import SwiftData

struct TodayView: View {

// lodad all data
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var undo: TodayUndo?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                let viewModel = TodayViewModel(plan: plans.first, now: AppClock.now())
                content(for: viewModel)
                    .animation(Motion.animation(reduceMotion: reduceMotion), value: viewModel.layout)
            }
            .background(Color.screenBackground)
            .navigationTitle("Today")
            .helpButtons(showsSettings: true)
        }
        .safeAreaInset(edge: .bottom) {
            if let undo {
                UndoBar(message: undo.message) {
                    Motion.perform(reduceMotion) {
                        undo.perform(context)
                        self.undo = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.animation(reduceMotion: reduceMotion), value: undo?.id)
        // the Undo bar goes away after 6 secs
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { undo = nil }
        }
    }

    // today view lgoic
    @ViewBuilder
    private func content(for viewModel: TodayViewModel) -> some View {
        switch viewModel.layout {
        case .noPlan:
            ContentUnavailableView("No plan yet",
                                   systemImage: "doc.text.viewfinder",
                                   description: Text("Scan your surgery papers and Remedy will turn them into a plan."))
        case .needsSurgeryDate:
            SurgeryDatePrompt(viewModel: viewModel)
        case .beforeSurgery, .surgeryDay:
            TodayBeforeView(viewModel: viewModel) { undo = $0 }
                .transition(.slideIn(reduceMotion: reduceMotion))
        case .afterSurgery:
            TodayAfterView(viewModel: viewModel) { undo = $0 }
                .transition(.slideIn(reduceMotion: reduceMotion))
        }
    }
}

// for when u need date
struct SurgeryDatePrompt: View {
    let viewModel: TodayViewModel

    @Environment(\.modelContext) private var context
    // UI only the date being picked
    @State private var date = Date()

    var body: some View {
        ScrollView {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.surgeryDatePrompt)
                        .font(.title2.bold())
                    Text(viewModel.surgeryDateExplanation)
                        .foregroundStyle(.secondary)
                    DatePicker("Surgery date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Button {
                        viewModel.saveSurgeryDate(date, in: context)
                    } label: {
                        Text("Save date")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    TodayView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    TodayView()
}
