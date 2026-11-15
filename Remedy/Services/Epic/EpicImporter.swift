//
//  EpicImporter.swift
//  Remedy
//
//  import from mychart start to finish
//

import AuthenticationServices
import Foundation
import os
import SwiftUI

// signs in, reads the record and maps it to a draft
enum EpicImporter {

    // sign in read and map
    static func importPlan(paper: PaperKind, using webAuth: WebAuthenticationSession) async throws -> RecordImport {
        guard EpicConfig.isSetUp else { throw EpicError.notSetUp }

        let token = try await SMARTAuth.signIn(using: webAuth)
        let client = FHIRClient(token: token)

        let medicines = try await client.medicines()
        let visits = try await client.visits()
        let surgeries = await client.surgeries()
        let papers = await client.papers()

        PlanReaders.log.info("MyChart: \(medicines.count) medicine orders, \(visits.count) visits, \(surgeries.count) surgeries, \(papers.count) papers")
        var draft = FHIRMapper.draft(medicines: medicines, visits: visits, surgeries: surgeries,
                                     paper: paper, now: AppClock.now())
        draft.paperSource = .hospitalRecord
        return RecordImport(draft: draft, papers: papers)
    }
}

// what goes wrong with MyChart in words the patient understands
enum EpicError: LocalizedError {
    case notSetUp
    case cancelled          // the patient closed the sign-in sheet (not an error to show)
    case signInFailed
    case signInExpired
    case notAllowed
    case couldNotReach
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notSetUp: return "MyChart import isn\u{2019}t set up in this version of Remedy."
        case .cancelled: return nil
        case .signInFailed: return "Signing in to MyChart didn\u{2019}t work. Please try again."
        case .signInExpired: return "Your MyChart sign-in ran out. Please sign in again."
        case .notAllowed: return "Your hospital didn\u{2019}t share that part of your record with Remedy. You can scan your papers instead."
        case .couldNotReach: return "We couldn\u{2019}t reach your hospital. Check your internet, or scan your papers instead."
        case .unreadable: return "Your hospital sent something we couldn\u{2019}t read. You can scan your papers instead."
        }
    }
}
