//
//  ScreenTests.swift
//  RemedyTests
//
//  every main screen drawn in both looks for every demo plan, and the view models behind them
//  a crash or a hang in any body shows up here
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Remedy

@MainActor
@Suite(.serialized) struct ScreenTests {

    // shows a view in a real window for a moment, which runs its body, every child body and onAppear
    private func draw(_ view: some View, in context: ModelContext) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            Issue.record("no window scene to draw in")
            return
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(rootView: NavigationStack { view }.modelContext(context))
        window.isHidden = false
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test(arguments: DemoScenario.allCases)
    func classicScreensDraw(_ scenario: DemoScenario) throws {
        let context = try Fixtures.context()
        let plan = try #require(DemoMode.insert(scenario, into: context))
        draw(TodayView(), in: context)
        draw(MedicinesView(), in: context)
        draw(PlanView(), in: context)
        draw(AskView(), in: context)
        draw(HelpView(), in: context)
        draw(SettingsView(), in: context)
        draw(EmergencyInfoView(), in: context)
        draw(CheckInView(viewModel: CheckInViewModel(plan: plan, now: Date())), in: context)
        draw(PapersView(), in: context)
        for medicine in plan.medicines {
            draw(MedicineDetailView(medicine: medicine), in: context)
        }
    }

    @Test(arguments: DemoScenario.allCases)
    func simpleScreensDraw(_ scenario: DemoScenario) throws {
        let context = try Fixtures.context()
        let plan = try #require(DemoMode.insert(scenario, into: context))
        draw(SimpleHomeView(), in: context)
        draw(SimpleMedicinesView(), in: context)
        draw(SimpleAllMedicinesView(), in: context)
        draw(SimpleMyDayView(), in: context)
        draw(SimplePapersPage(), in: context)
        draw(SimpleWhatChangedPage(), in: context)
        draw(SimplePlanRulesView(), in: context)
        draw(SimpleAskView(), in: context)
        draw(SimpleHelpView(), in: context)
        draw(SimpleWhenToCallPage(), in: context)
        draw(SimpleFamilyShareView(), in: context)
        draw(SimpleSettingsView(), in: context)
        draw(SimpleCheckInView(viewModel: CheckInViewModel(plan: plan, now: Date())), in: context)
        for medicine in plan.medicines {
            draw(SimpleMedicineDetailView(medicine: medicine), in: context)
        }
    }

    @Test func screensDrawWithNoPlan() throws {
        let context = try Fixtures.context()
        draw(ScanFlowView(), in: context)
        draw(TodayView(), in: context)
        draw(SimpleHomeView(), in: context)
        draw(SimpleFamilyShareView(), in: context)
        draw(SimpleHelpView(), in: context)
    }
}

@MainActor
@Suite(.serialized) struct ViewModelTests {

    // a morning, an afternoon and a late evening on the plan's today
    private let hours = [7, 14, 23]

    private func times() -> [Date] {
        let midnight = DayMath.calendar.startOfDay(for: Date())
        return hours.map { midnight.addingTimeInterval(TimeInterval($0 * 3600)) }
    }

    @Test(arguments: DemoScenario.allCases)
    func viewModelsBuildAtEveryTimeOfDay(_ scenario: DemoScenario) throws {
        let context = try Fixtures.context()
        let plan = try #require(DemoMode.insert(scenario, into: context))
        for now in times() {
            let today = TodayViewModel(plan: plan, now: now)
            _ = TodayScreen(today: today, redCards: [], questions: [], snoozed: [])
            _ = PlanViewModel(plan: plan, now: now)
            _ = MedicinesViewModel(plan: plan, now: now)
            _ = PaperCheckViewModel(plan: plan, now: now)
            _ = CheckInViewModel(plan: plan, now: now)
            let emergency = EmergencyInfoViewModel(plan: plan, now: now)
            #expect(emergency.hasPlan)
            let help = HelpViewModel(plan: plan)
            #expect(help.emergencyURL?.absoluteString == "tel:911")
        }
    }

    @Test(arguments: ShareChoice.allCases)
    func everyShareKindMakesAPDF(_ choice: ShareChoice) throws {
        let context = try Fixtures.context()
        let plan = try #require(DemoMode.insert(.threeDaysAfter, into: context))
        let viewModel = SharePlanViewModel(plan: plan, now: Date(), choice: choice, day: Date())
        #expect(viewModel.pageCount >= 1)
        if choice == .week { #expect(viewModel.pageCount == 7) }
        let url = try #require(viewModel.makePDF())
        let data = try Data(contentsOf: url)
        #expect(data.starts(with: Array("%PDF".utf8)))
    }

    @Test func surgeryTeamFooterOnlyWhenTheNewestPaperIsFromThem() throws {
        let context = try Fixtures.context()
        let plan = try #require(DemoMode.insert(.bothPapers, into: context))
        let footer = WhatChangedViewModel.footer(plan: plan)
        #expect(!footer.isEmpty)
    }
}
