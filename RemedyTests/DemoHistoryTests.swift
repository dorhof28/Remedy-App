//
//  DemoHistoryTests.swift
//  RemedyTests
//
//  the HSS demo papers and the past days filled in for the demo
//

import Foundation
import SwiftData
import Testing
@testable import Remedy

@MainActor
@Suite(.serialized) struct DemoHistoryTests {

    // the four papers at 2 PM on day 4, the time of the live demo
    private func ruthPlan(at minute: Int = 14 * 60) throws -> (CarePlan, ModelContext, Date) {
        let context = try Fixtures.context()
        var plan: CarePlan?
        for var draft in RuthDrafts.all() {
            for index in draft.medicines.indices { draft.medicines[index].isConfirmed = true }
            for index in draft.rules.indices { draft.rules[index].isConfirmed = true }
            for index in draft.tasks.indices { draft.tasks[index].isConfirmed = true }
            for index in draft.appointments.indices { draft.appointments[index].isConfirmed = true }
            plan = PlanImporter.save(draft, in: context)
        }
        let saved = try #require(plan)
        let now = DayMath.date(forDay: 4, minute: minute, from: RuthDrafts.surgery)
        return (saved, context, now)
    }

    @Test func papersShowEachPaperCheckColor() throws {
        let (plan, _, _) = try ruthPlan()
        let findings = PaperCheckReport.of(plan).result.findings
        let eliquis = findings.filter { $0.medicine.lowercased().contains("apixaban") || $0.medicine.lowercased().contains("eliquis") }
        // the heart doctor's 2 days against the 3 days on the other papers
        #expect(eliquis.contains { $0.color == .red }, "\(eliquis.map { ($0.color, $0.rule) })")
        // the discharge paper's restart date is followed after surgery
        #expect(eliquis.contains { $0.color == .blue }, "\(eliquis.map { ($0.color, $0.rule) })")
        // metoprolol the morning of surgery agrees
        #expect(findings.contains { $0.color == .green })
    }

    @Test func pastDaysAreFilledAndTodayHasOneMissedDose() throws {
        let (plan, context, now) = try ruthPlan()
        DemoHistory.fill(plan, now: now, in: context)
        let logs = plan.medicines.flatMap(\.doseLogs)
        #expect(logs.count > 30)
        // taken a few minutes after the dose time, never before it
        #expect(logs.allSatisfy { $0.loggedAt >= $0.scheduledFor })
        #expect(logs.filter { $0.status == .skipped }.count == 1)

        // today: the 6 AM tylenol is logged, one morning dose is left missed, nothing after now is touched
        let slots = DoseSchedule.slots(onDay: 4, plan: plan, now: now, skipped: PaperCheckReport.of(plan).skipped)
        let tylenol = try #require(slots.first { $0.medicine.name == "Acetaminophen" && $0.minute == 360 })
        #expect(tylenol.log?.status == .taken)
        #expect(slots.filter { $0.scheduledFor < now.addingTimeInterval(-3600) && $0.log == nil }.count == 1)
        #expect(slots.filter { $0.scheduledFor > now }.allSatisfy { $0.log == nil })

        // pain pills, check-ins for days 1 to 3, past to-dos done
        let oxycodone = try #require(plan.medicines.first { $0.name == "Oxycodone" })
        #expect(!oxycodone.doseLogs.isEmpty)
        let days = Set(try context.fetch(FetchDescriptor<CheckIn>()).map(\.day))
        #expect(days == [1, 2, 3])
        let pastTasksDone = plan.tasks.filter { ($0.dueDay ?? 99) < 4 }.allSatisfy { $0.isDone }
        #expect(pastTasksDone)
    }

    @Test func aPastDisagreementLeavesTodayButStaysOnThePapers() throws {
        let (plan, _, now) = try ruthPlan()
        // before surgery the eliquis stop days are still open
        let before = PaperCheckViewModel(plan: plan, now: DayMath.date(forDay: -5, minute: 600, from: RuthDrafts.surgery))
        #expect(before.redCards.contains { $0.finding.medicine.contains("Eliquis") })
        // on day 4 both papers have said stop for days, nothing is left to ask
        let after = PaperCheckViewModel(plan: plan, now: now)
        #expect(!after.redCards.contains { $0.finding.medicine.contains("Eliquis") },
                "\(after.redCards.map { ($0.finding.kind, $0.finding.rule, $0.finding.items.map { ($0.startDay, $0.endDay) }) })")
        #expect(after.blueNotes.contains { $0.isRed && $0.finding.medicine.contains("Eliquis") })
        // and no daily nag about it
        let reminders = AskByReminder.reminders(for: PaperCheckReport.of(plan).result.findings, surgeryDate: RuthDrafts.surgery,
                                                contactName: nil, now: now)
        #expect(!reminders.contains { $0.title.contains("Eliquis") })
    }

    @Test func bundledPapersMatchTheirAnswersAfterTheBlackout() throws {
        func squash(_ text: String) -> String { text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        for draft in RuthDrafts.withPages() {
            #expect(!draft.pages.isEmpty, "a sample paper is missing from the app")
            let text = squash(draft.pageText)
            // the fake patient's name never reaches the saved page text
            #expect(!text.contains("callahan"))
            let quotes = draft.medicines.map(\.quote) + draft.rules.map(\.quote) + draft.tasks.map(\.quote) + draft.appointments.map(\.quote)
            for quote in quotes { #expect(text.contains(squash(quote)), "\(quote)") }
        }
    }

    @Test func aVisitOnSeveralPapersIsOneVisit() throws {
        let (plan, _, _) = try ruthPlan()
        // the december 14 heart visit is on three papers, the first one had no address
        let heart = plan.appointments.filter { $0.title.contains("Okafor") }
        #expect(heart.count == 1)
        #expect(heart.first?.address.isEmpty == false)
        #expect(Set(plan.appointments.map(\.date)).count == plan.appointments.count)
    }

    @Test func fillingTwiceAddsNothing() throws {
        let (plan, context, now) = try ruthPlan()
        DemoHistory.fill(plan, now: now, in: context)
        let first = plan.medicines.flatMap(\.doseLogs).count
        DemoHistory.fill(plan, now: now, in: context)
        #expect(plan.medicines.flatMap(\.doseLogs).count == first)
        let count = try context.fetch(FetchDescriptor<CheckIn>()).count
        #expect(count == 3)
    }

    @Test func simpleMedicinesNeverSayTakeAMissedDoseNow() throws {
        let (plan, context, now) = try ruthPlan()
        DemoHistory.fill(plan, now: now, in: context)
        let cards = SimpleMedicinesScreen(plan: plan, now: now).cards
        let apixaban = try #require(cards.first { $0.title.lowercased().contains("apixaban") || $0.title.lowercased().contains("eliquis") })
        #expect(apixaban.status == "Missed 9 AM. Don\u{2019}t take an extra one.")
        // times read like 7 PM, not 19
        #expect(cards.contains { $0.status == "Next at 7 PM" })
        #expect(!cards.contains { $0.status.contains("19") || $0.status.contains("21") })
    }
}
