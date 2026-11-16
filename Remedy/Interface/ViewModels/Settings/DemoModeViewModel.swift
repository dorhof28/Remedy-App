//
//  DemoModeViewModel.swift
//  Remedy
//
//  Demo mode in Settings for both looks: fake patients, the fake today and the way back
//

import Foundation
import SwiftData

// the demo mode page: pick a fake patient and move the fake clock
struct DemoModeViewModel {

    var defaults: UserDefaults = .standard
    var store: DemoBackupStore = .live

    // MARK: - Words

    let toggleTitle = "Demo mode"
    let toggleNote = "Try Remedy with made-up plans and test papers. Everything in it is fake."
    let openTitle = "Open demo mode"
    let welcomeTitle = "Try a demo"
    let screenTitle = "Demo Mode"
    let intro = "Try Remedy with made-up patients. Everything here is pretend, and your own plan comes back when you leave."
    let patientsTitle = "Sample patients"
    let pickDateTitle = "Pretend today is"

    // the parts of the demo screen, everything that loads a plan first
    enum Section: String, CaseIterable, Identifiable {
        case papers, guide, today, exit
        var id: String { rawValue }

        // the classic segments, exit sits at the top of the load page
        static let segments: [Section] = [.papers, .guide, .today]

        var title: String {
            switch self {
            case .papers: return "Test Papers"
            case .guide: return "Testing Guide"
            case .today: return "Pretend today is"
            case .exit: return "Exit"
            }
        }

        var symbol: String {
            switch self {
            case .papers: return "doc.text.magnifyingglass"
            case .guide: return "safari"
            case .today: return "calendar"
            case .exit: return "arrow.uturn.backward.circle.fill"
            }
        }
    }
    let clockTitle = "Pretend today is"
    let resetClockTitle = "Back to real today"
    let toSurgeryTitle = "Jump to surgery day"
    let exitTitle = "Exit demo mode"
    let cancelTitle = "Cancel"
    let loadTitle = "Load demo plan"
    let otherPlansTitle = "More Sample Patients"
    let loadedBadge = "Showing"
    let loadWord = "Open"
    let loadingText = "Loading\u{2026}"
    let testingTitle = "For testing"
    let dateRowTitle = "Date"
    let leaveButton = "Leave"
    let doneButton = "Done"
    let samplePapersTitle = "Sample Papers"
    let samplePapersDetail = "The 4 papers behind HSS knee replacement. Open, share or add them."
    let samplePapersIntro = "Made-up papers in the same format as real hospital printouts. Open one to see it, then load HSS knee replacement to see what Remedy made from it. To show adding papers, share them to Files and add them from Remedy."
    let shareTitle = "Share"
    let readWithTitle = "Read papers with"
    let readWithAI = "Your AI"
    let readWithAnswers = "Expected answers"
    let readWithNote = "Your AI reads added papers with the AI picked in Settings, like Claude. Expected answers skips the AI and uses the answer key for the sample papers, so the result is the same every time. Only works in demo mode."
    let connectionTitle = "Check Connections"
    let connectionDetail = "MyChart and Health with a sample patient"

    // the everyday plans up top, the rest grouped below
    static let featured: [DemoScenario] = DemoScenario.scenarios(in: .featured)
    static let otherGroups: [DemoScenario.Group] = DemoScenario.Group.allCases.filter { $0 != .featured }

    // "Surgery in 12 days", "Surgery today", "5 days after surgery"
    static func whenText(_ scenario: DemoScenario) -> String {
        let days = scenario.surgeryInDays
        if days == 0 { return "Surgery today" }
        if days > 0 { return "Surgery in \(PlainText.count(days, "day"))" }
        return "\(PlainText.count(-days, "day")) after surgery"
    }

    // a real plan is only replaced after a yes, a fake one is swapped in one tap
    func asksBeforeLoading(hasRealPlan: Bool) -> Bool { hasRealPlan && !hasSavedPlan }

    // MARK: - State

    var isOn: Bool { defaults.bool(forKey: LaunchOptions.demoModeKey) }
    var shift: Int { LaunchOptions.clampedShift(defaults.integer(forKey: LaunchOptions.demoShiftKey)) }
    var loadedName: String? { defaults.string(forKey: LaunchOptions.demoLoadedKey) }
    // a fake plan replaced the real one, so leaving needs the way back
    var hasSavedPlan: Bool { store.exists }

    var statusText: String {
        loadedName.map { "Showing: \($0)" } ?? "No demo plan loaded yet"
    }

    // "Today", "3 days later", "1 day earlier"
    static func shiftWords(_ days: Int) -> String {
        if days == 0 { return "Real today" }
        let count = abs(days)
        return "\(count) \(count == 1 ? "day" : "days") \(days > 0 ? "later" : "earlier")"
    }

    // the shift that makes the fake today land on the surgery day
    static func shift(toReach date: Date, from realToday: Date) -> Int {
        let calendar = DayMath.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: realToday), to: calendar.startOfDay(for: date)).day ?? 0
        return LaunchOptions.clampedShift(days)
    }

    // MARK: - The warning before a plan is replaced

    func warningTitle(for scenario: DemoScenario) -> String { "Load \(scenario.title)?" }

    func warningMessage(hasPlan: Bool) -> String {
        if hasSavedPlan {
            return "This replaces the fake plan on screen. Your own plan is still saved safely and comes back when you exit demo mode."
        }
        if hasPlan {
            return "Your own plan, doses, chat and photos are copied to a safe place on this phone first. This fake plan then replaces them on screen. Tap Exit demo mode to get everything back. Anything you add while in demo mode is removed."
        }
        return "This fake plan replaces what is on screen. You have no plan yet, so Exit demo mode takes you back to the start."
    }

    var exitMessage: String {
        hasSavedPlan ? "Your own plan, doses, chat and photos come back. Anything you added in demo mode is removed."
                     : "Turns demo mode off."
    }

    // MARK: - Actions

    func turnOn() { DemoMode.turnOn(defaults: defaults) }

    // turning the switch off with nothing saved just ends the mode
    func turnOffWithoutPlan() { DemoMode.turnOff(defaults: defaults) }

    @discardableResult
    func moveToday(byDays days: Int) -> Int { DemoMode.moveToday(byDays: days, defaults: defaults) }

    func resetToday() { defaults.set(0, forKey: LaunchOptions.demoShiftKey) }

    // the fake today straight to a picked date
    func setToday(_ date: Date, realToday: Date = Date()) {
        defaults.set(Self.shift(toReach: date, from: realToday), forKey: LaunchOptions.demoShiftKey)
    }

    // moves the fake today to the plan's surgery day
    func jumpToSurgery(of plan: CarePlan?) {
        guard let date = plan?.surgeryDate else { return }
        defaults.set(Self.shift(toReach: date, from: Date()), forKey: LaunchOptions.demoShiftKey)
    }

    // the old plan waits in a copy, the fake one takes its place
    func load(_ scenario: DemoScenario, in context: ModelContext) async throws {
        try DemoMode.load(scenario, into: context, store: store, defaults: defaults)
        await refreshOutside(in: context, syncsCalendar: false)
    }

    // the real plan is back, its calendar comes back too
    func exit(in context: ModelContext) async throws {
        try DemoMode.exit(into: context, store: store, defaults: defaults)
        await refreshOutside(in: context, syncsCalendar: true)
    }

    func errorText(_ error: Error) -> String {
        "Something went wrong. Your own plan was not deleted. Please try again."
    }

    // reminders, widget and the calendar follow the plan on screen
    // the fake plan never goes into the real calendar
    func refreshOutside(in context: ModelContext, syncsCalendar: Bool) async {
        let plan = PlanActions.currentPlan(in: context)
        let now = AppClock.now()
        if CalendarService.hasSavedEvents(defaults: defaults) {
            await CalendarService.removePlan(defaults: defaults)
        }
        await LiveActivityManager.sync(plan: nil, now: now)
        if syncsCalendar, defaults.bool(forKey: CalendarService.planOnKey), let plan {
            await CalendarService.syncPlan(plan, defaults: defaults)
        }
        await NotificationService.shared.refresh(plan: plan, now: now)
        WidgetSnapshotMaker.save(plan: plan, now: now)
        await LiveActivityManager.sync(plan: plan, now: now)
    }
}
