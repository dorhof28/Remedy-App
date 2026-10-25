//
//  FHIRTypes.swift
//  Remedy
//
//  the few fhir fields we read
//

import Foundation

// a page of search results
nonisolated struct FHIRBundle<Resource: Decodable>: Decodable {
    struct Entry: Decodable {
        let resource: Resource?
    }
    struct Link: Decodable {
        let relation: String?
        let url: URL?
    }
    let entry: [Entry]?
    let link: [Link]?

    // the next page of results if there is one
    var nextPage: URL? { link?.first { $0.relation == "next" }?.url }
}

// text with codes like a medicine name or a visit type
nonisolated struct FHIRConcept: Decodable {
    struct Coding: Decodable { let display: String? }
    let text: String?
    let coding: [Coding]?

    var bestText: String? { text ?? coding?.first?.display }
}

// link to another record
nonisolated struct FHIRReference: Decodable {
    let reference: String?      // "Practitioner/abc"
    let display: String?
}

// MARK: - MedicationRequest (a medicine order)

// also reads older shapes from apple health records
nonisolated struct FHIRMedicationRequest: Decodable {
    let resourceType: String?               // bundles can also hold warnings (OperationOutcome)
    let status: String?                     // active, on-hold, stopped, completed...
    let medicationCodeableConcept: FHIRConcept?
    let medicationReference: FHIRReference?
    let dosageInstruction: [Dosage]?
    let dosage: [Dosage]?                   // MedicationStatement
    let reasonCode: [FHIRConcept]?

    // the first dosage whichever field it came in
    var firstDosage: Dosage? { (dosageInstruction ?? dosage)?.first }

    struct Dosage: Decodable {
        let text: String?                   // "Take 1 tablet by mouth every 8 hours"
        let patientInstruction: String?
        let asNeededBoolean: Bool?
        let timing: Timing?
        let doseAndRate: [DoseAndRate]?
    }
    struct Timing: Decodable {
        let `repeat`: Repeat?
    }
    struct Repeat: Decodable {
        let frequency: Int?                 // 3 ...
        let period: Double?                 // ... per 1 ...
        let periodUnit: String?             // ... "d" (day) or "h" (hour)
        let periodUnits: String?            // same, in FHIR DSTU2
        let timeOfDay: [String]?            // "08:00:00"
    }
    struct DoseAndRate: Decodable {
        let doseQuantity: Quantity?
    }
    struct Quantity: Decodable {
        let value: Double?
        let unit: String?
    }
}

// MARK: - Appointment (a visit or a surgery)

// a visit or surgery
nonisolated struct FHIRAppointment: Decodable {
    let resourceType: String?
    let status: String?                     // booked, pending, cancelled...
    let start: String?                      // "2026-11-02T14:30:00Z"
    let description: String?
    let serviceType: [FHIRConcept]?
    let participant: [Participant]?
    let patientInstruction: String?
    let comment: String?

    struct Participant: Decodable {
        let actor: FHIRReference?
    }
}
