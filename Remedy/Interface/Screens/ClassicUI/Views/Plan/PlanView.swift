//
//  PlanView.swift
//  Remedy
//
//  classic plan tab (screen 39): next visit, rules now, the timeline, to-dos, then more
//

import SwiftUI
import SwiftData

// where a plan row goes
enum PlanRoute: Hashable {
    case day(Int)
    case rules
    case page(PlanPage)
    case surgery
}

// classic plan tab
struct PlanView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var context

    // UI only share, add, what is being edited and which sheets are open
    @State private var isSharing = false
    @State private var editing: PlanEditTarget?
    @State private var isChoosing = false
    @State private var pendingAdd: PlanEditTarget?
    @State private var isAddingPaper = false
    @State private var pendingPaper = false
    @State private var openRule: CareRule?
    @State private var showsTimeline = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { _ in
                content(PlanScreen(plan: plans.first, now: AppClock.now()))
            }
            .navigationTitle(PlanScreen.title)
            .navigationBarTitleDisplayMode(.large)
            .helpButtons()
            .sampleDataFooter()
            // DEBUG ONLY -demoOpenPlanPage checkIns opens that page for screenshots
            .onAppear {
                #if DEBUG
                let name = UserDefaults.standard.string(forKey: "demoOpenPlanPage")
                if name == "checkIns", path.isEmpty { path.append(PlanRoute.page(.checkIns)) }
                #endif
            }
            .sheet(isPresented: $isSharing) { SharePlanSheet() }
            .sheet(isPresented: $isChoosing, onDismiss: {
                // open the editor once the choice sheet is gone
                if let next = pendingAdd { editing = next; pendingAdd = nil }
                if pendingPaper { isAddingPaper = true; pendingPaper = false }
            }) {
                PlanAddSheet { id in
                    if id == PlanAddSheet.paperID { pendingPaper = true } else { pendingAdd = PlanAddChoice.target(for: id) }
                    isChoosing = false
                }
                .compactSheet()
            }
            .sheet(item: $editing) { target in
                if let plan = plans.first { editor(target, plan: plan) }
            }
            .sheet(isPresented: $isAddingPaper) {
                ScanFlowView(isAddingPapers: true, planHasSurgeryDate: plans.first?.surgeryDate != nil)
            }
            .sheet(item: $openRule) { RuleSheet(rule: $0) }
            .sheet(isPresented: $showsTimeline) { PlanTimelineSheet() }
            .navigationDestination(for: MedicineInstruction.self) { MedicineDetailView(medicine: $0) }
            .navigationDestination(for: Appointment.self) { AppointmentDetailView(appointment: $0) }
            .navigationDestination(for: PlanRoute.self) { route in
                switch route {
                case .day(let day): DayView(day: day)
                case .rules: InstructionsView()
                case .surgery: SurgeryView()
                case .page(let page): PlanPageView(page: page)
                }
            }
            .navigationDestination(for: PlanPage.self) { PlanPageView(page: $0) }
        }
    }

    @ViewBuilder
    private func content(_ screen: PlanScreen) -> some View {
        if !screen.hasPlan {
            HeroScreen(symbol: "calendar", title: screen.emptyTitle, text: screen.emptyText) {
                PrimaryButton(title: screen.addPapersButton, symbol: "camera") { isAddingPaper = true }
            }
        } else {
            List {
                if let visit = screen.nextVisit {
                    Section {
                        ActionCard(style: .card, eyebrow: screen.nextEyebrow, eyebrowSymbol: "calendar",
                                   title: visit.title, subtitle: visit.subtitle) {
                            VisitActionTiles(appointment: visit.appointment)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { path.append(visit.appointment) }
                        .plainListRow()
                    }
                }
                if !screen.ruleLines.isEmpty {
                    Section {
                        ForEach(screen.ruleLines) { row($0, screen) }
                    } header: {
                        ListSectionHeader(title: screen.rulesTitle, trailing: screen.seeAllButton) { path.append(PlanRoute.rules) }
                    }
                }
                if !screen.timelineLines.isEmpty {
                    // the timeline opens in a sheet so the plan stays short
                    Section {
                        Button { showsTimeline = true } label: {
                            ListRow(symbol: "calendar.day.timeline.left", title: screen.timelineTitle,
                                    value: "\(screen.timelineLines.count)", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    ForEach(screen.taskLines) { row($0, screen) }
                    Button { isChoosing = true } label: {
                        ListRow(symbol: "plus", title: PlanAddChoice.rowTitle)
                    }
                    .buttonStyle(.plain)
                } header: {
                    ListSectionHeader(title: screen.tasksTitle)
                }
                Section {
                    ForEach(screen.moreLines) { row($0, screen) }
                } header: {
                    ListSectionHeader(title: screen.moreTitle)
                }
            }
            .remedyList()
        }
    }

    @ViewBuilder
    private func row(_ line: PlanLine, _ screen: PlanScreen) -> some View {
        let label = ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                            subtitleTone: line.subtitleTone, showsChevron: line.opens)
        Button { open(line.target, screen) } label: { label }
            .buttonStyle(.plain)
            .disabled(!line.opens)
    }

    private func open(_ target: PlanLine.Target, _ screen: PlanScreen) {
        guard let plan = screen.plan else { return }
        switch target {
        case .none: break
        case .day(let day): path.append(PlanRoute.day(day))
        case .visit(let id):
            if let visit = plan.appointments.first(where: { $0.persistentModelID == id }) { path.append(visit) }
        case .task(let id):
            if let task = plan.tasks.first(where: { $0.persistentModelID == id }) { editing = .task(task) }
        case .rule(let id):
            openRule = plan.rules.first { $0.persistentModelID == id }
        case .page(let page): path.append(PlanRoute.page(page))
        case .share: isSharing = true
        case .surgery: path.append(PlanRoute.surgery)
        }
    }

    @ViewBuilder
    private func editor(_ target: PlanEditTarget, plan: CarePlan) -> some View {
        switch target {
        case .medicine(let medicine): MedicineEditView(medicine: medicine, plan: plan, now: AppClock.now())
        case .visit(let visit): AppointmentEditView(appointment: visit, plan: plan, now: AppClock.now())
        case .task(let task): TaskEditView(task: task, plan: plan, now: AppClock.now())
        }
    }
}

// the plan timeline in its own sheet, a day or surgery opens inside it
struct PlanTimelineSheet: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            let screen = PlanScreen(plan: plans.first, now: AppClock.now())
            List {
                ForEach(screen.timelineLines) { line in
                    Button { open(line.target) } label: {
                        ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                                subtitleTone: line.subtitleTone, showsChevron: line.opens)
                    }
                    .buttonStyle(.plain)
                    .disabled(!line.opens)
                }
            }
            .remedyList()
            .navigationTitle(screen.timelineTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .navigationDestination(for: PlanRoute.self) { route in
                switch route {
                case .day(let day): DayView(day: day)
                case .surgery: SurgeryView()
                case .rules: InstructionsView()
                case .page(let page): PlanPageView(page: page)
                }
            }
            .navigationDestination(for: Appointment.self) { AppointmentDetailView(appointment: $0) }
        }
    }

    private func open(_ target: PlanLine.Target) {
        switch target {
        case .day(let day): path.append(PlanRoute.day(day))
        case .surgery: path.append(PlanRoute.surgery)
        case .page(let page): path.append(PlanRoute.page(page))
        case .visit(let id):
            if let visit = plans.first?.appointments.first(where: { $0.persistentModelID == id }) { path.append(visit) }
        default: break
        }
    }
}

// 98, the Add choices, short enough for a sheet that fits them
struct PlanAddSheet: View {
    // a paper comes first, then the things the patient adds by hand
    static let paperID = "paper"
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlanAddChoice.sheetOptions, id: \.id) { option in
                        Button { onPick(option.id) } label: {
                            ListRow(symbol: option.symbol, title: option.title, subtitle: option.detail, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    ListSectionHeader(title: PlanAddChoice.heading)
                        .font(.title2.bold())
                } footer: {
                    Text(PlanAddChoice.footer).font(.footnote).foregroundStyle(Color.ink2)
                }
            }
            .remedyList()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    PlanView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    PlanView()
}
