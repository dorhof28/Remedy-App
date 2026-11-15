//
//  SimpleTodayList.swift
//  Remedy
//
//  simple my day (80): one thing at a time with before and next, and pick a day
//

import SwiftUI
import SwiftData

// the whole day, one tap from home
struct SimpleMyDayView: View {
    @State private var calledTick = 0

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    // redraws when today's check-in is saved
    @Query private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    // UI only the day shown, nil is today, and the day picker
    @State private var pickedDay: Int?
    @State private var showsPicker = false
    @State private var undo: TodayUndo?
    @State private var showsCheckIn = false
    @State private var showsHospital = false
    @State private var successTick = 0
    // UI only which thing of the day is showing, nil is the first one still to do
    @State private var index: Int?

    // opens on a given plan day, nil is today
    init(startDay: Int? = nil) {
        _pickedDay = State(initialValue: startDay)
    }

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = TodayViewModel(plan: plans.first, now: AppClock.now())
            let kit = SimpleDayKit(plan: plans.first, now: AppClock.now())
            let shownDay = pickedDay.flatMap { $0 == kit.today ? nil : $0 }
            let picked = shownDay == nil ? 0 : 1
            let items = picked == 0
                ? viewModel.simpleDayItems(checkInDone: viewModel.checkIn.today(in: context) != nil)
                : []
            let dayTitle = PlanViewModel(plan: plans.first, now: AppClock.now()).dayListTitle(shownDay ?? kit.today)
            let current = items.isEmpty ? 0 : min(index ?? SimpleMyDayWords.startIndex(items), items.count - 1)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    SimpleTopBar(title: nil, spoken: "", onBack: { dismiss() }) { EmptyView() }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(SimpleMyDayWords.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.ink)
                        Text(shownDay == nil ? SimpleMyDayWords.position(current, of: items.count) : dayTitle)
                            .font(.title3)
                            .foregroundStyle(Color.ink2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    if picked == 0 {
                        ForEach(viewModel.stopQuestions()) { question in
                            stopQuestion(question, viewModel)
                        }
                        if viewModel.showsReady {
                            SimpleReadyView(list: viewModel.ready)
                        }
                    }

                    if let shownDay {
                        SimpleOtherDayView(day: shownDay)
                    } else if items.isEmpty {
                        Text(TodayViewModel.simpleNothingOnDayText)
                            .font(.title3)
                            .foregroundStyle(Color.ink2)
                            .padding(.vertical, 8)
                    } else {
                        let item = items[current]
                        oneThing(item, viewModel)
                            .id(item.id)
                            .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
                                // swiping does the same as before and next
                                if drag.translation.width < -40 { step(1, count: items.count, from: current) }
                                if drag.translation.width > 40 { step(-1, count: items.count, from: current) }
                            })
                        if SimpleMyDayWords.showsMissedNote(item, in: items) {
                            Text(SimpleMyDayWords.missedNote)
                                .font(.title3)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Tone.caution.soft))
                        }
                        HStack(spacing: 12) {
                            Button { step(-1, count: items.count, from: current) } label: {
                                Label(SimpleMyDayWords.before, systemImage: "chevron.left")
                            }
                            .buttonStyle(SimpleButtonStyle(kind: .gray))
                            .disabled(current == 0)
                            Button { step(1, count: items.count, from: current) } label: {
                                Label(SimpleMyDayWords.next, systemImage: "chevron.right")
                                    .labelStyle(TrailingIconLabelStyle())
                            }
                            .buttonStyle(SimpleButtonStyle(kind: .gray))
                            .disabled(current >= items.count - 1)
                        }
                    }

                    if kit.canStep {
                        Button { showsPicker = true } label: {
                            Label(SimpleMyDayWords.pickDay, systemImage: "calendar")
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .gray))
                        if shownDay != nil {
                            Button(SimpleMyDayWords.backToToday) { pickedDay = nil }
                                .buttonStyle(SimpleButtonStyle(kind: .gray))
                        }
                    }
                }
                .padding(.horizontal, Spacing.simpleEdge)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .animation(Motion.animation(reduceMotion: reduceMotion), value: current)
            }
            .scrollBounceBehavior(.basedOnSize)
            .sheet(isPresented: $showsCheckIn) { SimpleCheckInView(viewModel: viewModel.checkIn) }
            // DEBUG ONLY -demoOpenSimpleCheckIn YES opens the check-in for screenshots
            .onAppear {
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "demoOpenSimpleCheckIn") { showsCheckIn = true }
                #endif
            }
            .sheet(isPresented: $showsPicker) { dayPicker(kit, shownDay: shownDay) }
        }
        .remedyBackground()
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if let undo {
                SimpleUndoCard(undo: undo) {
                    Motion.perform(reduceMotion) {
                        undo.perform(context)
                        self.undo = nil
                    }
                } onClose: {
                    Motion.perform(reduceMotion) { self.undo = nil }
                }
                .padding(.horizontal, Spacing.simpleEdge)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .animation(Motion.animation(reduceMotion: reduceMotion), value: undo?.id)
        .sensoryFeedback(.success, trigger: successTick)
        .sheet(isPresented: $showsHospital) { SimpleHospitalSheet(plan: plans.first) }
        .onDisappear { Speaker.stop() }
        #if DEBUG
        // screenshots open a day by its plan day number
        .onAppear {
            if pickedDay == nil, UserDefaults.standard.object(forKey: "demoSimpleDay") != nil {
                pickedDay = UserDefaults.standard.integer(forKey: "demoSimpleDay")
            }
        }
        #endif
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled { undo = nil }
        }
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button {
            Motion.perform(reduceMotion, action)
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.ink)
                .frame(width: Spacing.tapSimple, height: Spacing.tapSimple)
                .background(Circle().fill(Color.surface))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    // a big calendar to land on any day of the plan
    private func dayPicker(_ kit: SimpleDayKit, shownDay: Int?) -> some View {
        let binding = Binding<Date>(
            get: { kit.date(forDay: shownDay ?? kit.today) },
            set: { pickedDay = kit.day(for: $0) }
        )
        return NavigationStack {
            VStack(spacing: 16) {
                if let range = kit.dateRange {
                    DatePicker(SimpleDayKit.pickTitle, selection: binding, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                Button(SimpleDayKit.pickerDone) { showsPicker = false }
                    .buttonStyle(SimpleButtonStyle())
                Spacer(minLength: 0)
            }
            .padding(Spacing.simpleEdge)
            .remedyBackground()
            .navigationTitle(SimpleDayKit.pickTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    // moves to the thing before or after
    private func step(_ amount: Int, count: Int, from current: Int) {
        let next = current + amount
        guard next >= 0, next < count else { return }
        Motion.perform(reduceMotion) { index = next }
    }

    // the one thing on screen: when, what and how much, a medicine or visit opens on tap
    @ViewBuilder
    private func oneThing(_ item: SimpleDayItem, _ viewModel: TodayViewModel) -> some View {
        let card = VStack(alignment: .leading, spacing: 6) {
            Text(SimpleMyDayWords.time(item))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(item.state == .late ? Color.dangerInk : Color.accentInk)
            Text(item.title)
                .font(.largeTitle.bold())
                .foregroundStyle(item.isDone ? Color.ink2 : Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .simpleOutlineCard(isNext: false)
        .accessibilityElement(children: .combine)
        if let medicine = item.medicine {
            NavigationLink(value: medicine) { card }.buttonStyle(.plain)
        } else if let appointment = item.appointment {
            NavigationLink(value: appointment) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }

    // the card's one button
    private func perform(_ item: SimpleDayItem, _ viewModel: TodayViewModel) {
        switch item.kind {
        case .dose: done(viewModel.simpleTake(item.doses, in: context))
        case .asNeeded: if let row = item.asNeeded { done(viewModel.takeAsNeeded(row, in: context)) }
        case .stop: done(viewModel.putAwayStopsToday(in: context))
        case .checkIn: showsCheckIn = true
        case .todo: if let task = item.task { done(viewModel.toggle(task, in: context)) }
        case .goal: if let goal = item.goal { done(viewModel.simpleAddOne(to: goal, in: context)) }
        case .fillIn: showsHospital = true
        case .visit, .surgery, .rule: break
        }
    }

    // runs a change and keeps its undo for the undo bar
    private func done(_ change: @autoclosure () -> TodayUndo?) {
        Motion.perform(reduceMotion) { undo = change() }
        if undo != nil { successTick += 1 }
    }

    // soft question on a stop day, never blocks, a yes shows who to call until I Called
    @ViewBuilder
    private func stopQuestion(_ question: StopQuestion, _ viewModel: TodayViewModel) -> some View {
        if question.answer == .yes && !question.showsCallCard {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if question.answer == .yes {
                    Label(question.callEyebrow, systemImage: "exclamationmark.triangle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Tone.caution.color)
                    Text(question.callTitle)
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(question.callText)
                        .font(.title3)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = question.callURL {
                        Link(destination: url) { Label(question.callButton, systemImage: "phone.fill") }
                            .buttonStyle(SimpleButtonStyle())
                    }
                    Button(question.calledButton) {
                        Motion.perform(reduceMotion) { LastDoseQuestion.markCalled(question.medicine); calledTick += 1 }
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                } else {
                    Text(question.shortQuestion)
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(question.answer == nil ? question.dialogDetail : question.followUp)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    if question.answer == nil {
                        Button(question.yesSomeTitle) {
                            done(viewModel.answerLastDose(.yes, for: question, in: context))
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .gray))
                        Button(LastDoseQuestion.noTitle) {
                            done(viewModel.answerLastDose(.no, for: question, in: context))
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .gray))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .simpleOutlineCard(isNext: false, tone: question.answer == .yes ? .caution : .neutral)
            .accessibilityElement(children: .contain)
            .id(calledTick)
        }
    }
}
