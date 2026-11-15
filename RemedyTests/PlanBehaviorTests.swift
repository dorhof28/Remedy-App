//
//  PlanBehaviorTests.swift
//  RemedyTests
//
//  whole demo plans through the rules: the paper check, reminders and Ask
//

import Foundation
import SwiftData
import Testing
@testable import Remedy

@MainActor
@Suite(.serialized) struct PlanBehaviorTests {

    private func load(_ scenario: DemoScenario) throws -> CarePlan {
        try #require(DemoMode.insert(scenario, into: try Fixtures.context()))
    }

    @Test func conflictingPapersShowARedCard() throws {
        let plan = try load(.conflictingPapers)
        let report = PaperCheckReport.of(plan)
        #expect(report.result.findings.contains { $0.color == .red })
        #expect(!PaperCheckViewModel(plan: plan, now: Date()).redCards.isEmpty)
    }

    @Test func onePaperHasNothingToCompare() throws {
        let plan = try load(.beforeOnly)
        #expect(!PaperCheckReport.of(plan).result.findings.contains { $0.color == .red })
    }

    @Test(arguments: DemoScenario.allCases)
    func remindersAreNeverInThePastAndNeverRepeat(_ scenario: DemoScenario) throws {
        let plan = try load(scenario)
        let now = Date()
        let items = ReminderPlan.itemsWithCheck(for: plan, now: now)
        #expect(items.allSatisfy { $0.date > now }, "\(scenario)")
        #expect(Set(items.map(\.id)).count == items.count, "\(scenario)")
        #expect(items.allSatisfy { !$0.title.isEmpty }, "\(scenario)")
    }

    @Test func plansLongOverHaveNoDoseReminders() throws {
        let plan = try load(.longAgo)
        let doses = ReminderPlan.itemsWithCheck(for: plan, now: Date()).filter { $0.kind == .dose }
        let active = plan.medicines.contains { DoseSchedule.isActive($0, on: 120) && !$0.timesOfDay.isEmpty }
        #expect(active || doses.isEmpty)
    }

    @Test func askAnswersFromThePapersNeverInventing() throws {
        let plan = try load(.threeDaysAfter)
        let today = DoseSchedule.today(for: plan, now: Date()) ?? 0
        let shower = AskAnswers.answerWithCheck("Can I shower?", plan: plan, today: today, now: Date())
        #expect(!shower.text.isEmpty)
        // a question the papers cannot answer points to the surgeon, never a guess
        let unknown = AskAnswers.answerWithCheck("Can I go skydiving next week?", plan: plan, today: today, now: Date())
        #expect(!unknown.text.isEmpty)
        // any quote it shows is really on the papers
        if !unknown.quote.isEmpty {
            let pages = plan.medicines.map(\.quote) + plan.rules.map(\.quote) + plan.tasks.map(\.quote)
            #expect(pages.contains { $0.contains(unknown.quote) || unknown.quote.contains($0) })
        }
    }

    @Test(arguments: DemoScenario.allCases)
    func askSuggestionsNameRealMedicines(_ scenario: DemoScenario) throws {
        let plan = try load(scenario)
        let groups = plan.medicines.filter(\.isGroup).flatMap { [$0.name] + $0.alsoKnownAs }.map { $0.lowercased() }
        let suggestions = AskViewModel(plan: plan, messages: [], now: Date()).suggestions
        // a group like any other nsaid is not a box name a patient can ask about
        #expect(!suggestions.contains { question in groups.contains { question.lowercased().contains("take \($0)?") } }, "\(scenario)")
    }

    @Test func surgeonPhoneIsTheCareTeams() throws {
        let plan = try load(.threeDaysAfter)
        let phone = AskAnswers.surgeonPhone(plan)
        #expect(!phone.isEmpty)
        #expect(phone.filter(\.isNumber).suffix(7).hasPrefix("55501"))
    }
}
