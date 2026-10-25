//
//  TestDatabase.swift
//  RemedyTests
//
//  fresh in memory database for each test
//

import SwiftData
@testable import Remedy

enum TestDatabase {

    // an empty in-memory database with every model
    static func empty() throws -> ModelContainer {
        let schema = Schema(RemedySchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    // an in-memory database filled with the sample patient
    static func withSamplePlan(surgeryInDays: Int = 9) throws -> ModelContainer {
        let container = try empty()
        SamplePlan.insert(into: container.mainContext, surgeryInDays: surgeryInDays)
        return container
    }
}
