//
//  HealthService.swift
//  Remedy
//
//  reads health records and steps from apple health
//

import Foundation
import HealthKit

enum HealthService {

    // the Settings switch "Show my steps on Today"
    static let stepsOnKey = "healthStepsOn"

    private static let store = HKHealthStore()

    // false on iPad and Mac
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // can this phone hold hospital records
    static var canReadRecords: Bool { isAvailable && store.supportsHealthRecords() }

    // MARK: - Health Records

    // every medicine record as the hospital's own FHIR JSON
    static func medicineRecords() async throws -> [Data] {
        guard let type = HKObjectType.clinicalType(forIdentifier: .medicationRecord) else { return [] }
        try await store.requestAuthorization(toShare: [], read: [type])
        let query = HKSampleQueryDescriptor(predicates: [.clinicalRecord(type: type)], sortDescriptors: [])
        let records = try await query.result(for: store)
        return records.compactMap { $0.fhirResource?.data }
    }

    // MARK: - Steps

    // asks once
    static func askForSteps() async {
        try? await store.requestAuthorization(toShare: [], read: [HKQuantityType(.stepCount)])
    }

    // steps since midnight or nil if there are none to show
    static func stepsToday(now: Date) async -> Int? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.stepCount)
        let midnight = Calendar.current.startOfDay(for: now)
        let today = HKQuery.predicateForSamples(withStart: midnight, end: now)
        let query = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: today),
                                                options: .cumulativeSum)
        guard let sum = try? await query.result(for: store)?.sumQuantity() else { return nil }
        let steps = Int(sum.doubleValue(for: .count()))
        return steps > 0 ? steps : nil
    }

    // "2340 steps today " or nil
    static func stepsTodayText(now: Date) async -> String? {
        guard let steps = await stepsToday(now: now) else { return nil }
        return "\(steps.formatted()) steps today (Apple Health)"
    }
}
