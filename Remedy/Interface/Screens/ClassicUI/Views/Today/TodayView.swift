//
//  TodayView.swift
//  Remedy
//
//  classic today tab (screens 14 15 18 19 22 26 27): alerts, one loud card, then short lists
//

import SwiftUI
import SwiftData

// where a row on Today goes when tapped
enum TodayRoute: Hashable {
    case ready
    case goals
    case visit(Appointment)
    case disagree(String)
    case day(Int)
}

// classic today tab
struct TodayView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    // redraws when the office's answer is saved
    @Query private var checkNotes: [PaperCheckNote]
    @Query private var logs: [DoseLog]

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.switchTab) private var switchTab
    @Environment(\.openURL) private var openURL

    // UI only what is open
    @State private var undo: TodayUndo?
    @State private var isAddingPaper = false
    @State private var showsHospital = false
    @State private var route: TodayRoute?
    @State private var isPickingDay = false
    @State private var pickedDay: Int?
    @State private var missed: DoseListRow?
    @State private var notNow: DoseListRow?
    @State private var stopQuestion: StopQuestion?
    @State private var showsHelpContacts = false
    @State private var showsDone = false
    // bumps when a card is put off so the screen redraws
    @State private var snoozeTick = 0

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                let screen = makeScreen()
                content(screen)
                    .navigationTitle(screen.title)
                    .navigationDestination(item: $route) { destination(for: $0, screen: screen) }
                    .sheet(isPresented: $isPickingDay, onDismiss: {
                        // open the day once the sheet is gone
                        if let day = pickedDay { route = .day(day); pickedDay = nil }
                    }) {
                        PickDaySheet { pickedDay = $0 }
                    }
                    .confirmationDialog(stopQuestion?.shortQuestion ?? "", isPresented: isPresented($stopQuestion),
                                        titleVisibility: .visible, presenting: stopQuestion) { question in
                        Button(question.yesSomeTitle) { act { screen.today.answerLastDose(.yes, for: question, in: context) } }
                        Button(LastDoseQuestion.noTitle) { act { screen.today.answerLastDose(.no, for: question, in: context) } }
                        Button("Cancel", role: .cancel) {}
                    } message: { question in
                        Text(question.dialogDetail)
                    }
                    .sheet(item: $missed) { row in
                        MissedDoseSheet(question: TodayScreen.missedQuestion(row), detail: screen.missedDetail(row)) { took in
                            act { screen.answerMissed(row, took: took, in: context) }
                        }
                    }
            }
            .navigationBarTitleDisplayMode(.large)
            .helpButtons()
            .sampleDataFooter()
            .sheet(isPresented: $isAddingPaper) {
                ScanFlowView(isAddingPapers: true, planHasSurgeryDate: plans.first?.surgeryDate != nil)
            }
            .sheet(isPresented: $showsHospital) { HospitalDetailsSheet(plan: plans.first) }
            .sheet(isPresented: $showsHelpContacts) { HelpView() }
        }
        // the undo stays until it is closed or something else is logged
        .safeAreaInset(edge: .bottom) {
            if let undo {
                UndoBar(message: undo.message, onUndo: {
                    Motion.perform(reduceMotion) {
                        undo.perform(context)
                        self.undo = nil
                    }
                }, onClose: {
                    Motion.perform(reduceMotion) { self.undo = nil }
                })
                .padding(.horizontal, Spacing.screenEdge)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.animation(reduceMotion: reduceMotion), value: undo?.id)
    }

    private func makeScreen() -> TodayScreen {
        let today = TodayViewModel(plan: plans.first, now: AppClock.now())
        _ = snoozeTick
        return TodayScreen(today: today,
                           redCards: PaperCheckViewModel(plan: today.plan, now: today.now).redCards,
                           questions: today.stopQuestions(),
                           snoozed: TodayScreen.snoozed(now: today.now))
    }

    // MARK: - States

    @ViewBuilder
    private func content(_ screen: TodayScreen) -> some View {
        switch screen.state {
        case .noPlan:
            HeroScreen(symbol: "doc.text", title: screen.emptyTitle, text: screen.emptyText) {
                PrimaryButton(title: screen.addPapersButton, symbol: "camera") { isAddingPaper = true }
            }
        case .needsDate:
            SurgeryDatePrompt(viewModel: screen.today)
        case .finished:
            dayList(screen) {
                HeroMessage(symbol: "checkmark.circle", tone: .good, title: screen.finishedTitle, text: screen.finishedText)
                    .frame(maxWidth: .infinity)
                    .plainListRow()
            }
        case .day:
            dayList(screen) { EmptyView() }
        }
    }

    // MARK: - The day

    private func dayList<Top: View>(_ screen: TodayScreen, @ViewBuilder top: () -> Top) -> some View {
        List {
            Section {
                top()
            } header: {
                if !screen.subtitle.isEmpty {
                    Text(screen.subtitle)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                        .textCase(nil)
                        .padding(.leading, -16)
                }
            }
            ForEach(screen.stopCalls) { question in
                Section { stopCall(question).plainListRow() }
            }
            if !screen.alerts.isEmpty {
                Section {
                    ForEach(screen.alerts) { line in
                        row(line, screen: screen)
                            .listRowBackground(line.tone.soft)
                    }
                }
            }
            if let card = screen.card {
                Section { topCard(card, screen: screen).plainListRow() }
            }
            if !screen.afterCardAlerts.isEmpty {
                Section {
                    ForEach(screen.afterCardAlerts) { line in
                        row(line, screen: screen)
                            .listRowBackground(line.tone.soft)
                    }
                }
            }
            ForEach(screen.groups) { group in
                if group.id == TodayScreen.doneGroupID {
                    // done items wait in a sheet so the open ones stay on screen
                    Section {
                        Button { showsDone = true } label: {
                            ListRow(symbol: "checkmark.circle", tone: .good, title: group.title,
                                    value: "\(group.lines.count)", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Section {
                        ForEach(group.lines) { row($0, screen: screen) }
                    } header: {
                        if !group.title.isEmpty { ListSectionHeader(title: group.title) }
                    }
                }
            }
        }
        .remedyList()
        .sheet(isPresented: $showsDone) { doneSheet(screen) }
        .animation(Motion.animation(reduceMotion: reduceMotion), value: screen.card?.id)
    }

    // what is done today, to-dos can still be unticked here
    private func doneSheet(_ screen: TodayScreen) -> some View {
        let lines = screen.groups.first { $0.id == TodayScreen.doneGroupID }?.lines ?? []
        return NavigationStack {
            List {
                ForEach(lines) { row($0, screen: screen) }
            }
            .remedyList()
            .navigationTitle(TodayScreen.doneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showsDone = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // 90, who to call after a yes, never whether surgery can go ahead
    private func stopCall(_ question: StopQuestion) -> some View {
        ActionCard(style: .caution, eyebrow: question.callEyebrow, eyebrowSymbol: "exclamationmark.triangle",
                   title: question.callTitle, text: question.callText) {
            VStack(spacing: 4) {
                if let url = question.callURL {
                    PrimaryButton(title: question.callButton, symbol: "phone.fill") { openURL(url) }
                } else {
                    PrimaryButton(title: question.addNumberButton, symbol: "phone.fill") { showsHelpContacts = true }
                }
                Button(question.calledButton) {
                    Motion.perform(reduceMotion) { LastDoseQuestion.markCalled(question.medicine); snoozeTick += 1 }
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentInk)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            }
            .padding(.top, 8)
        }
    }

    // the one loud thing to do now
    private func topCard(_ card: TodayTopCard, screen: TodayScreen) -> some View {
        ActionCard(style: card.style == .stop ? .stop : .next, eyebrow: card.eyebrow, eyebrowSymbol: card.symbol,
                   title: card.title, text: card.text) {
            VStack(spacing: 4) {
                if !card.buttonTitle.isEmpty {
                    PrimaryButton(title: card.buttonTitle, symbol: card.buttonSymbol) { run(card.action, screen: screen) }
                        .sensoryFeedback(.success, trigger: undo?.id)
                }
                if card.showsNotNow, case .takeDose(let row) = card.action {
                    Button(screen.notNowButton) { notNow = row }
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentInk)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                        // shown from the button so it opens next to it
                        .confirmationDialog(notNow.map(screen.notNowTitle) ?? "", isPresented: isPresented($notNow),
                                            titleVisibility: .visible, presenting: notNow) { row in
                            Button(TodayScreen.remindButton) { remindLater(row, screen: screen) }
                            Button(TodayScreen.skipButton, role: .destructive) { act { screen.today.skip(row, in: context) } }
                            Button("Cancel", role: .cancel) {}
                        } message: { row in
                            Text(screen.notNowMessage(row))
                        }
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func row(_ line: TodayLine, screen: TodayScreen) -> some View {
        if line.isToDo {
            Button { open(line.target, screen: screen) } label: {
                ListRow(title: line.title, subtitle: line.subtitle, subtitleTone: line.subtitleTone) { EmptyView() }
                    .leadingMark(line.isChecked ? "checkmark.circle.fill" : "circle", isOn: line.isChecked, onTone: .toneGreen)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(line.isChecked ? .isSelected : [])
        } else if line.opens {
            Button { open(line.target, screen: screen) } label: { lineRow(line) }
                .buttonStyle(.plain)
        } else {
            // nothing to open, so a plain row that does not look switched off
            lineRow(line)
        }
    }

    private func lineRow(_ line: TodayLine) -> some View {
        ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                subtitleTone: line.subtitleTone, value: line.value, showsChevron: line.opens)
    }

    // MARK: - What taps do

    private func run(_ action: TodayTopCard.Action, screen: TodayScreen) {
        switch action {
        case .takeDose(let row):
            act {
                screen.today.toggle(row, in: context).map { TodayUndo(message: screen.takenMessage(row), perform: $0.perform) }
            }
        case .stopToday: act { screen.today.putAwayStopsToday(in: context) }
        case .directions(let url): openURL(url)
        case .none: break
        }
    }

    private func open(_ target: TodayTarget, screen: TodayScreen) {
        switch target {
        case .none: break
        case .disagree(let card): route = .disagree(card.id)
        case .missed(let row): missed = row
        case .stopQuestion(let question): stopQuestion = question
        case .medicinesTab: switchTab?(.medicines)
        case .visit(let visit): route = .visit(visit)
        case .todo(let row): act { screen.today.toggle(row, in: context) }
        case .goals: route = .goals
        case .hospital: showsHospital = true
        case .ready: route = .ready
        case .anotherDay: isPickingDay = true
        case .addPapers: isAddingPaper = true
        }
    }

    @ViewBuilder
    private func destination(for route: TodayRoute, screen: TodayScreen) -> some View {
        switch route {
        case .ready: ReadyForSurgeryView(plan: plans.first)
        case .goals: GoalsView()
        case .visit(let visit): AppointmentDetailView(appointment: visit)
        case .day(let day): DayView(day: day)
        case .disagree(let id):
            if let card = PaperCheckViewModel(plan: plans.first, now: AppClock.now()).redCards.first(where: { $0.id == id }) {
                PapersDisagreeView(card: card)
            }
        }
    }

    // put off for 30 minutes, with a reminder when reminders are on
    private func remindLater(_ row: DoseListRow, screen: TodayScreen) {
        TodayScreen.snooze(TodayScreen.cardID(row), now: screen.today.now)
        snoozeTick += 1
        let title = "Time for \(row.name)"
        let body = row.how.isEmpty ? "" : "Take \(row.how)."
        Task { await NotificationService.shared.remindAgain(title: title, body: body, inMinutes: TodayScreen.remindMinutes) }
    }

    // runs a dose or to-do change and keeps its undo for the undo bar
    private func act(_ change: () -> TodayUndo?) {
        Motion.perform(reduceMotion) { undo = change() ?? undo }
    }

    // an optional item as a bool for sheets and alerts
    private func isPresented<T>(_ item: Binding<T?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

// for when u need date, scrolls only when it does not fit
struct SurgeryDatePrompt: View {
    let viewModel: TodayViewModel

    var body: some View {
        ScrollView {
            SurgeryDateCard(viewModel: viewModel)
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.scrollBottom)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// the date question itself, no scroll view so it can sit inside another screen
struct SurgeryDateCard: View {
    let viewModel: TodayViewModel
    var simple = false

    @Environment(\.modelContext) private var context
    // UI only the date being picked
    @State private var date = Date()

    var body: some View {
        if simple {
            VStack(alignment: .leading, spacing: 12) {
                Label(viewModel.surgeryDateEyebrow, systemImage: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentInk)
                Text(viewModel.surgeryDatePrompt).font(.title.bold())
                Text(viewModel.surgeryDateWhy).font(.title3).foregroundStyle(Color.ink)
                calendar
                Button("Save Date") { viewModel.saveSurgeryDate(date, in: context) }
                    .buttonStyle(SimpleButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .simpleOutlineCard()
        } else {
            ActionCard(style: .next, eyebrow: viewModel.surgeryDateEyebrow, eyebrowSymbol: "calendar",
                       title: viewModel.surgeryDatePrompt, text: viewModel.surgeryDateWhy) {
                VStack(spacing: 12) {
                    calendar
                    PrimaryButton(title: "Save Date") { viewModel.saveSurgeryDate(date, in: context) }
                }
            }
        }
    }

    // the system calendar with the visit days marked, Remedy never guesses the surgery day
    private var calendar: some View {
        PlanCalendarPicker(selection: $date, surgery: nil, visits: (viewModel.plan?.appointments ?? []).map(\.date))
            .frame(minHeight: 340)
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    TodayView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    TodayView()
}
