//
//  HealthService.swift
//  Remedy
//
//  reads health records and steps from apple health
//

import Foundation
import HealthKit

// steps and health records access
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

}
