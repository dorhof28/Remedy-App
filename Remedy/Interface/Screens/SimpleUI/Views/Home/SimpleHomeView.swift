//
//  SimpleHomeView.swift
//  Remedy
//
//  simple home (79): the day, the one thing to do now, four big tiles and settings
//

import SwiftUI
import SwiftData

// every page simple home pushes by value
// the raw value is the debug -demoOpenSimpleScreen name
enum SimpleRoute: String, Hashable {
    case today
    case medicines
    case instructions
    case papers
    case ask
    case help
    case settings
}

// navigation for the simple look: home and the pages it opens
struct SimpleRootView: View {
    // UI only the pushed pages
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SimpleHomeView()
                .navigationDestination(for: SimpleRoute.self) { route in
                    switch route {
                    case .today: SimpleMyDayView()
                    case .medicines: SimpleMedicinesView()
                    case .instructions: SimplePlanRulesView()
                    case .papers: SimplePapersPage()
                    case .ask: SimpleAskView()
                    case .help: SimpleHelpView()
                    case .settings: SimpleSettingsView()
                    }
                }
                .navigationDestination(for: MedicineInstruction.self) { medicine in
                    SimpleMedicineDetailView(medicine: medicine)
                }
                .navigationDestination(for: Appointment.self) { appointment in
                    SimpleVisitView(appointment: appointment)
                }
        }
        #if DEBUG
        // screenshots open one page straight away
        .onAppear {
            guard path.isEmpty, let name = UserDefaults.standard.string(forKey: "demoOpenSimpleScreen"), !name.isEmpty else { return }
            if let route = SimpleRoute(rawValue: name) { path.append(route) }
        }
        #endif
    }
}

// simple home: the one thing to do now and the main tiles
struct SimpleHomeView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    // redraws the cards when the office's answer is saved
    @Query private var checkNotes: [PaperCheckNote]
    // redraws when today's check-in is saved
    @Query private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    // UI only the "Done" with undo
    @State private var undo: TodayUndo?
    // UI only sheets
    @State private var showsHospital = false
    @State private var showsCheckIn = false
    @State private var resolving: PaperCheckCardData?
    @State private var showingPapers: PaperCheckCardData?
    // UI only the green tick before the card moves on
    @State private var isTakingDose = false
    // UI only a tap on the phone for each saved change
    @State private var successTick = 0
    // UI only things put off with "Not now", back next time home opens
    @State private var snoozed: Set<String> = []
    // UI only the same settings sheet as classic (59)
    @State private var showsSettings = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = TodayViewModel(plan: plans.first, now: AppClock.now())
            let items = viewModel.simpleDayItems(checkInDone: viewModel.checkIn.today(in: context) != nil)
            let redCard = PaperCheckViewModel(plan: plans.first, now: viewModel.now).redCards.first
            // fits one screen: two rows after, then one, then none, then a little smaller
            // fits one screen, else scrolls at the biggest text sizes
            ViewThatFits(in: .vertical) {
                page(viewModel, items: items, redCard: redCard, afterLimit: 2)
                ScrollView { page(viewModel, items: items, redCard: redCard, afterLimit: 2) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .sheet(isPresented: $showsCheckIn) { SimpleCheckInView(viewModel: viewModel.checkIn) }
        }
        .remedyBackground()
        .checkInTimePrompt(plan: plans.first, simple: true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(Motion.animation(reduceMotion: reduceMotion), value: undo?.id)
        .sensoryFeedback(.success, trigger: successTick)
        .sheet(isPresented: $showsHospital) { SimpleHospitalSheet(plan: plans.first) }
        .sheet(isPresented: $showsSettings) { SettingsView() }
        .sheet(item: $resolving) { ResolveSheet(card: $0) }
        .sheet(item: $showingPapers) { card in papersSheet(card) }
        .onDisappear { Speaker.stop() }
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled { undo = nil }
        }
        #if DEBUG
        // screenshots open the check-in straight away
        .onAppear { if UserDefaults.standard.bool(forKey: "demoOpenCheckIn") { showsCheckIn = true } }
        #endif
    }

    // MARK: - Page

    private func page(_ viewModel: TodayViewModel, items: [SimpleDayItem], redCard: PaperCheckCardData?, afterLimit: Int) -> some View {
        let doNow = redCard == nil ? TodayViewModel.simpleDoNow(items, snoozed: snoozed) : nil
        // with papers that disagree on top, the next things are simply the first ones
        let after = TodayViewModel.simpleAfterThat(items, leading: doNow, limit: afterLimit)
        let spoken = viewModel.simpleSpokenHome(doNow: doNow, after: after,
                                                paperCheck: redCard.map { "\($0.simpleTitle). \($0.simpleHomeDetail)" })
        return VStack(alignment: .leading, spacing: Spacing.betweenCards) {
            header(viewModel, spoken: spoken)

            if viewModel.layout == .needsSurgeryDate {
                SurgeryDateCard(viewModel: viewModel, simple: true)
            } else if let undo {
                SimpleUndoCard(undo: undo) {
                    Motion.perform(reduceMotion) {
                        undo.perform(context)
                        self.undo = nil
                    }
                } onClose: {
                    Motion.perform(reduceMotion) { self.undo = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else if let redCard {
                doFirstCard(redCard)
            } else if let doNow {
                doNowCard(doNow, viewModel)
            } else {
                allDoneCard(viewModel)
            }

            if viewModel.layout != .noPlan && viewModel.layout != .needsSurgeryDate {
                tiles
            }
        }
        .padding(.horizontal, Spacing.simpleEdge)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Header

    // the weekday as the title, the surgery day under it, read aloud on the right
    private func header(_ viewModel: TodayViewModel, spoken: String) -> some View {
        let screen = SimpleHomeScreen(base: viewModel)
        // read aloud goes under the title at the largest sizes so the day is never split
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(screen.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(screen.subtitle)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ReadAloudTile(text: spoken, title: screen.readAloud)
        }
    }

    // MARK: - Tiles

    // my day, medicines, ask and help, then settings
    private var tiles: some View {
        let screen = SimpleHomeScreen(base: TodayViewModel(plan: plans.first, now: AppClock.now()))
        return VStack(spacing: 12) {
            SimpleTileGrid {
                ForEach(screen.tiles) { tile in
                    NavigationLink(value: tile.route) {
                        SimpleBigTile(title: tile.title, symbol: tile.symbol, tint: tile.isHelp ? Color.dangerInk : Color.accentInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { showsSettings = true } label: {
                Label(screen.settingsButton, systemImage: "gearshape")
            }
            .buttonStyle(SimpleButtonStyle(kind: .gray))
        }
    }

    // MARK: - Do this now

    private func doNowCard(_ item: SimpleDayItem, _ viewModel: TodayViewModel) -> some View {
        let primary = SimpleHomeScreen.button(item)
        let late = item.state == .late
        return VStack(alignment: .leading, spacing: 8) {
            Text(SimpleHomeScreen.eyebrow(item))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(late ? Color.dangerInk : Color.accentInk)
            Text(item.title)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let primary {
                Button {
                    perform(item, viewModel)
                } label: {
                    Label(isTakingDose ? "Taken" : primary, systemImage: isTakingDose ? "checkmark.circle.fill" : primarySymbol(item))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(SimpleButtonStyle())
                .disabled(isTakingDose)
                .padding(.top, 8)
            } else if let appointment = item.appointment {
                NavigationLink(value: appointment) { Text("See the Visit") }
                    .buttonStyle(SimpleButtonStyle(kind: .gray))
            } else if let medicine = item.medicine {
                NavigationLink(value: medicine) { Text("See This Medicine") }
                    .buttonStyle(SimpleButtonStyle(kind: .gray))
            }
        }
        .simpleOutlineCard()
        .id(item.id)
        .transition(.push(from: .trailing))
        .accessibilityElement(children: .contain)
    }

    // a tick only where something gets marked done
    private func primarySymbol(_ item: SimpleDayItem) -> String {
        switch item.kind {
        case .checkIn: return "heart"
        case .fillIn: return "square.and.pencil"
        default: return "checkmark"
        }
    }

    // the uppercase label over a big card
    private func eyebrow(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 6) {
            if !symbol.isEmpty { Image(systemName: symbol) }
            Text(text.uppercased())
        }
        .font(.headline.bold())
        .foregroundStyle(color)
    }

    // the card's main button
    private func perform(_ item: SimpleDayItem, _ viewModel: TodayViewModel) {
        switch item.kind {
        case .dose:
            takeDoses(item.doses, viewModel)
        case .stop:
            done(viewModel.putAwayStopsToday(in: context))
        case .checkIn:
            showsCheckIn = true
        case .todo:
            if let task = item.task { done(viewModel.toggle(task, in: context)) }
        case .goal:
            if let goal = item.goal { done(viewModel.simpleAddOne(to: goal, in: context)) }
        case .fillIn:
            showsHospital = true
        case .asNeeded:
            if let row = item.asNeeded { done(viewModel.takeAsNeeded(row, in: context)) }
        case .visit, .surgery, .rule:
            break
        }
    }

    // the tick turns green with a tap on the phone, then done with an undo
    private func takeDoses(_ rows: [DoseListRow], _ viewModel: TodayViewModel) {
        guard !isTakingDose else { return }
        successTick += 1
        Motion.perform(reduceMotion) { isTakingDose = true }
        Task { @MainActor in
            try? await Task.sleep(for: TodayTiming.celebrate(reduceMotion: reduceMotion))
            Motion.perform(reduceMotion) {
                undo = viewModel.simpleTake(rows, in: context)
                isTakingDose = false
            }
        }
    }

    // saves a change, shows done with undo and taps the phone
    private func done(_ change: @autoclosure () -> TodayUndo?) {
        Motion.perform(reduceMotion) { undo = change() }
        if undo != nil { successTick += 1 }
    }

    // MARK: - Do this first: papers disagree

    // never hidden and never dismissed, it stays until the office's answer is saved
    private func doFirstCard(_ card: PaperCheckCardData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow(TodayViewModel.simpleDoFirstTitle, symbol: "exclamationmark.triangle", color: .dangerInk)
            Text(card.simpleTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.simpleHomeDetail)
                .font(.title3)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let url = card.phoneURL {
                Link(destination: url) {
                    Label(card.callTitle, systemImage: "phone.fill")
                }
                .buttonStyle(SimpleButtonStyle(kind: .danger))
                .padding(.top, 4)
            } else {
                Label(card.simpleHomeNoPhone, systemImage: "phone")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.dangerInk)
            }
            Button(card.resolveButton) { resolving = card }
                .buttonStyle(SimpleButtonStyle(kind: .plain))
            Button { showingPapers = card } label: {
                Label("What each paper says", systemImage: "doc.on.doc")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, minHeight: Spacing.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simpleToneCard(.dangerSoft, edge: .dangerInk)
        .accessibilityElement(children: .contain)
    }

    // the whole card with each paper's words, from the medicines look
    private func papersSheet(_ card: PaperCheckCardData) -> some View {
        NavigationStack {
            ScrollView {
                SimplePaperCheckCard(card: card)
                    .padding(Spacing.simpleEdge)
            }
            .remedyBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingPapers = nil }
                }
            }
        }
    }

    // MARK: - All done

    private func allDoneCard(_ viewModel: TodayViewModel) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(TodayViewModel.simpleAllDoneTitle)
                    .font(.title.bold())
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(viewModel.simpleAllDoneDetail)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // the two capsules from the app icon
            ZStack {
                Capsule().fill(Color.accentFill).frame(width: 22, height: 56).rotationEffect(.degrees(-35)).offset(x: -10)
                Capsule().fill(Color.secondFill).frame(width: 22, height: 56).rotationEffect(.degrees(35)).offset(x: 10)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simpleToneCard(.secondSoft)
        .accessibilityElement(children: .combine)
    }

}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    SimpleRootView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    SimpleRootView()
}
