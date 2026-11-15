//
//  SpeedTests.swift
//  RemedyTests
//
//  how long the busiest screens take to work out their content
//

import Testing
import Foundation
import SwiftData
@testable import Remedy

@MainActor
@Suite(.serialized) struct SpeedTests {

    // one today screen build in milliseconds, averaged over many
    private func average(_ runs: Int = 40, _ work: () -> Void) -> Double {
        let start = Date()
        for _ in 0..<runs { work() }
        return Date().timeIntervalSince(start) * 1000 / Double(runs)
    }

    @Test func todayAndHomeBuildQuickly() throws {
        let context = try Fixtures.context()
        SamplePlan.insert(into: context, surgeryInDays: -3)
        let plan = try #require(try context.fetch(FetchDescriptor<CarePlan>()).first)
        let now = Date()
        let classic = average {
            let today = TodayViewModel(plan: plan, now: now)
            _ = TodayScreen(today: today, redCards: PaperCheckViewModel(plan: plan, now: now).redCards,
                            questions: today.stopQuestions(), snoozed: [])
        }
        let simple = average {
            let today = TodayViewModel(plan: plan, now: now)
            _ = today.simpleDayItems(checkInDone: false)
        }
        try? "classic \(classic) simple \(simple)".write(toFile: NSTemporaryDirectory() + "remedy-speed.txt", atomically: true, encoding: .utf8)
        print("speed classic today \(String(format: "%.2f", classic)) ms, simple home \(String(format: "%.2f", simple)) ms")
        // a redraw must stay well under one frame budget of work
        #expect(classic < 50)
        #expect(simple < 50)
    }

    // the other busy paths, the cold paper check is the slow one the cache hides
    @Test func otherPathsBuildQuickly() throws {
        let context = try Fixtures.context()
        SamplePlan.insert(into: context, surgeryInDays: -3)
        let plan = try #require(try context.fetch(FetchDescriptor<CarePlan>()).first)
        let now = Date()
        let times: [(String, Double)] = [
            ("paperCheckCold", average(10) { _ = PaperCheckInput(plan: plan).result }),
            ("fingerprint", average { _ = PaperCheckInput.fingerprint(of: plan) }),
            ("medicines", average { _ = MedicinesViewModel(plan: plan, now: now).gapRows }),
            ("plan", average {
                let model = PlanViewModel(plan: plan, now: now)
                _ = (model.overviewRows, model.visitRows, model.taskRows, model.nowReminderGroups)
            }),
            ("widget", average { _ = WidgetSnapshotMaker.current(plan: plan, now: now) }),
            ("reminders", average(10) { _ = ReminderPlan.itemsWithCheck(for: plan, now: now) })
        ]
        let text = times.map { "\($0.0) \(String(format: "%.2f", $0.1))" }.joined(separator: "\n")
        try? text.write(toFile: NSTemporaryDirectory() + "remedy-speed2.txt", atomically: true, encoding: .utf8)
        // a redraw must stay well under one frame budget of work, the cold check and reminders run rarely
        for (name, ms) in times { #expect(ms < (name == "paperCheckCold" || name == "reminders" ? 500 : 50), "\(name) \(ms) ms") }
    }
}
