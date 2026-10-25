//
//  HealthRecordsImporter.swift
//  Remedy
//
//  imports medicines from apple health records
//

import Foundation
import os

enum HealthRecordsImporter {

    // health records to a draft
    static func importPlan(paper: PaperKind) async throws -> DraftPlan {
        guard HealthService.canReadRecords else { throw HealthImportError.notOnThisPhone }

        let records: [Data]
        do {
            records = try await HealthService.medicineRecords()
        } catch {
            throw HealthImportError.notAllowed
        }

        // each record is one medicine
        let decoder = JSONDecoder()
        let medicines = records.compactMap { try? decoder.decode(FHIRMedicationRequest.self, from: $0) }

        var draft = FHIRMapper.draft(medicines: medicines, visits: [], surgeries: [],
                                     paper: paper, now: AppClock.now())
        draft.source = .appleHealth
        guard !draft.medicines.isEmpty else { throw HealthImportError.nothingFound }
        PlanReaders.log.info("Apple Health: \(records.count) records, \(draft.medicines.count) current medicines")
        return draft
    }
}

// errors in plain words
enum HealthImportError: LocalizedError {
    case notOnThisPhone
    case notAllowed
    case nothingFound

    var errorDescription: String? {
        switch self {
        case .notOnThisPhone:
            return "Health Records aren\u{2019}t available on this device."
        case .notAllowed:
            return "Remedy wasn\u{2019}t allowed to read your Health Records. You can change that in the Health app."
        case .nothingFound:
            return "No current medicines in your Health Records. Connect your hospital in the Health app (Browse \u{2192} Health Records), or scan your papers."
        }
    }
}
