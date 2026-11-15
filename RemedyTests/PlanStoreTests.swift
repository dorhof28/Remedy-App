//
//  PlanStoreTests.swift
//  RemedyTests
//
//  saving a checked draft, the backup file, and every demo plan
//

import Foundation
import SwiftData
import Testing
@testable import Remedy

@MainActor
@Suite(.serialized) struct PlanStoreTests {

    private func draft() -> DraftPlan {
        var draft = DraftPlan(paper: .beforeSurgery)
        draft.procedure = "Right knee replacement"
        draft.surgeryDate = Fixtures.date("2026-11-20")
        draft.printedDate = Fixtures.date("2026-11-01")
        draft.hospitalName = "Lakeside Health (SAMPLE)"
        draft.medicines = [
            DraftMedicine(name: "Ibuprofen", action: .stop, startDay: -7, endDay: 0, quote: "Stop ibuprofen 7 days before", isConfirmed: true),
            DraftMedicine(name: "Aspirin", action: .take, timesOfDay: [480, 1200], quote: "Aspirin twice a day", isConfirmed: true),
            DraftMedicine(name: "Vitamin E", action: .stop, quote: "Stop vitamin E", isConfirmed: false),
        ]
        draft.tasks = [DraftTask(title: "Shower with the special soap", dueDay: -1, quote: "Shower the night before", isConfirmed: true)]
        draft.appointments = [DraftAppointment(title: "Pre-op testing", date: Fixtures.date("2026-11-17 10:00"),
                                               phone: "2015550142", quote: "Pre-op testing", isConfirmed: true)]
        return draft
    }

    @Test func onlyConfirmedItemsAreSaved() throws {
        let context = try Fixtures.context()
        let plan = PlanImporter.save(draft(), in: context)
        #expect(plan.procedure == "Right knee replacement")
        #expect(plan.medicines.map(\.name).sorted() == ["Aspirin", "Ibuprofen"])
        #expect(plan.tasks.count == 1)
        #expect(plan.appointments.count == 1)
        #expect(try context.fetch(FetchDescriptor<Paper>()).count == 1)
    }

    @Test func secondPaperJoinsTheSamePlan() throws {
        let context = try Fixtures.context()
        let first = PlanImporter.save(draft(), in: context)
        var after = DraftPlan(paper: .afterSurgery)
        after.surgeryDate = Fixtures.date("2026-11-20")
        after.medicines = [DraftMedicine(name: "Oxycodone", action: .takeAsNeeded, quote: "as needed", isConfirmed: true)]
        let second = PlanImporter.save(after, in: context)
        #expect(first.persistentModelID == second.persistentModelID)
        #expect(try context.fetch(FetchDescriptor<CarePlan>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Paper>()).count == 2)
    }

    @Test func backupRoundTripsThroughJSON() throws {
        let context = try Fixtures.context()
        PlanImporter.save(draft(), in: context)
        let snapshot = try BackupSnapshot.make(from: context, now: Fixtures.date("2026-11-15"))
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BackupSnapshot.self, from: data)

        let fresh = try Fixtures.context()
        try decoded.restore(into: fresh)
        let plans = try fresh.fetch(FetchDescriptor<CarePlan>())
        #expect(plans.count == 1)
        #expect(plans[0].procedure == "Right knee replacement")
        #expect(plans[0].medicines.count == 2)
        #expect(plans[0].appointments.first?.phone == "2015550142")
    }

    @Test(arguments: DemoScenario.allCases)
    func everyDemoPlanLoads(_ scenario: DemoScenario) throws {
        let context = try Fixtures.context()
        let plan = try #require(DemoMode.insert(scenario, into: context))
        #expect(plan.isSample)
        #expect(!plan.medicines.isEmpty)
        // fake data only: every phone is a 555-01xx number
        for phone in plan.contacts.map(\.phone) + plan.appointments.map(\.phone) where !phone.isEmpty {
            let digits = phone.filter(\.isNumber)
            #expect(digits.suffix(7).hasPrefix("55501"), "\(scenario) has \(phone)")
        }
    }
}
