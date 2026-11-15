//
//  DayView.swift
//  Remedy
//
//  classic one day (screen 42): a plain list, before and next step through the days, swiping does the same
//

import SwiftUI
import SwiftData

// classic page for one plan day
struct DayView: View {
    @State var day: Int

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only the to-do being edited
    @State private var editingTask: CareTask?
    @State private var opened: DayLineTarget?

    var body: some View {
        let screen = DayScreen(plan: plans.first, day: day, now: AppClock.now())
        List {
            Section {
            } header: {
                Text(screen.subtitle)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
                    .textCase(nil)
                    .padding(.leading, -12)
            }
            if screen.groups.isEmpty {
                Section {
                    Text(screen.emptyText).font(.body).foregroundStyle(Color.ink2)
                }
            }
            ForEach(screen.groups) { group in
                Section {
                    ForEach(group.lines) { row($0) }
                } header: {
                    ListSectionHeader(title: group.title)
                }
            }
            Section {
                stepButtons(screen).plainListRow()
            }
        }
        .remedyList()
        .gesture(DragGesture(minimumDistance: 40).onEnded { drag in
            guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
            step(drag.translation.width < 0 ? 1 : -1)
        })
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(screen.readAloudButton) { Speaker.toggle(screen.spoken) }
                    .accessibilityHint("Reads the day out loud. Tap again to stop.")
            }
        }
        .navigationDestination(item: $opened) { target in
            switch target {
            case .medicine(let medicine): MedicineDetailView(medicine: medicine)
            case .visit(let visit): AppointmentDetailView(appointment: visit)
            }
        }
        .sheet(item: $editingTask) { task in
            if let plan = plans.first { TaskEditView(task: task, plan: plan, now: AppClock.now()) }
        }
    }

    @ViewBuilder
    private func row(_ line: DayLine) -> some View {
        let label = ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                            showsChevron: line.opens)
        if let medicine = line.medicine {
            Button { opened = .medicine(medicine) } label: { label }.buttonStyle(.plain)
        } else if let visit = line.appointment {
            Button { opened = .visit(visit) } label: { label }.buttonStyle(.plain)
        } else if let task = line.task {
            Button { editingTask = task } label: { label }.buttonStyle(.plain)
        } else {
            label
        }
    }

    // before and next, side by side, stacked at accessibility sizes
    private func stepButtons(_ screen: DayScreen) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { stepPair(screen) }
            VStack(spacing: 10) { stepPair(screen) }
        }
    }

    @ViewBuilder
    private func stepPair(_ screen: DayScreen) -> some View {
        SecondaryButton(title: screen.previousTitle, symbol: "chevron.left") { step(-1) }
            .accessibilityLabel("Before, \(screen.previousTitle)")
        SecondaryButton(title: screen.nextTitle, symbol: "chevron.right") { step(1) }
            .accessibilityLabel("Next, \(screen.nextTitle)")
    }

    private func step(_ by: Int) {
        Motion.perform(reduceMotion) { day += by }
    }
}

// where a day row goes
enum DayLineTarget: Hashable {
    case medicine(MedicineInstruction)
    case visit(Appointment)
}
