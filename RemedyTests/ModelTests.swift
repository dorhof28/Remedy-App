//
//  ModelTests.swift
//  RemedyTests
//
//  tests for the models and sample data
//

import Foundation
import Testing
import SwiftData
@testable import Remedy

struct ModelTests {

    @Test("The sample patient makes exactly one plan")
    func samplePlanMakesOnePlan() throws {
        let container = try TestDatabase.withSamplePlan()
        let plans = try container.mainContext.fetch(FetchDescriptor<CarePlan>())
        #expect(plans.count == 1)
    }

    @Test("Surgery is the number of whole days away we asked for")
    func surgeryDateIsWholeDays() throws {
        let container = try TestDatabase.withSamplePlan(surgeryInDays: 4)
        let plan = try #require(try container.mainContext.fetch(FetchDescriptor<CarePlan>()).first)
        let surgeryDate = try #require(plan.surgeryDate)

        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: today, to: surgeryDate).day
        #expect(days == 4)
    }

    @Test("The HSS page has 7 things to stop before surgery")
    func hssStopList() throws {
        let container = try TestDatabase.withSamplePlan()
        let plan = try #require(try container.mainContext.fetch(FetchDescriptor<CarePlan>()).first)

        // the stop list from the sample paper
        let stops = plan.medicines.filter { $0.paper == .beforeSurgery && $0.action == .stop }
        #expect(stops.count == 7)

        // every one of them starts before surgery
        #expect(stops.allSatisfy { ($0.startDay ?? 0) < 0 })
    }

    @Test("Every medicine, rule and task says where it came from")
    func everythingHasAQuote() throws {
        let container = try TestDatabase.withSamplePlan()
        let plan = try #require(try container.mainContext.fetch(FetchDescriptor<CarePlan>()).first)

        #expect(plan.medicines.allSatisfy { !$0.quote.isEmpty })
        #expect(plan.rules.allSatisfy { !$0.quote.isEmpty })
        #expect(plan.tasks.allSatisfy { !$0.quote.isEmpty })
    }

    @Test("A dose log links to its medicine both ways")
    func doseLogLinksBothWays() throws {
        let container = try TestDatabase.withSamplePlan()
        let context = container.mainContext
        let plan = try #require(try context.fetch(FetchDescriptor<CarePlan>()).first)
        let aspirin = try #require(plan.medicines.first { $0.name == "Aspirin 81 mg" })

        // insert first then link
        let log = DoseLog(scheduledFor: Date(), status: .taken)
        context.insert(log)
        log.medicine = aspirin

        #expect(aspirin.doseLogs.count == 1)
        #expect(aspirin.doseLogs.first?.status == .taken)
    }

    @Test("Deleting the plan deletes everything in it")
    func deletingPlanCascades() throws {
        let container = try TestDatabase.withSamplePlan()
        let context = container.mainContext
        let plan = try #require(try context.fetch(FetchDescriptor<CarePlan>()).first)

        context.delete(plan)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<MedicineInstruction>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CareTask>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SourceDocument>()) == 0)
    }
}
