//
//  EpicTests.swift
//  RemedyTests
//
//  tests for pkce and the fhir mapper
//

import Foundation
import Testing
@testable import Remedy

struct PKCETests {

    @Test("PKCE matches the official example in RFC 7636, Appendix B")
    func rfcExample() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mJ92IUP96wfo2Q2MzL3bZ9Glr9Fh5Q")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("A new PKCE is random and web-address safe")
    func randomAndSafe() {
        let a = PKCE(), b = PKCE()
        #expect(a.verifier != b.verifier)
        #expect(a.verifier.count == 43)          // 32 bytes in base64url, no padding
        #expect(!a.challenge.contains { "+/=".contains($0) })
    }
}

struct FHIRMapperTests {

    // a small search result shaped like Epic's with a warning mixed in
    let medicinesJSON = """
    {
      "resourceType": "Bundle",
      "entry": [
        { "resource": {
            "resourceType": "MedicationRequest", "status": "active",
            "medicationCodeableConcept": { "text": "acetaminophen (TYLENOL) 500 MG tablet" },
            "dosageInstruction": [{
              "text": "Take 2 tablets by mouth every 8 hours",
              "timing": { "repeat": { "frequency": 1, "period": 8, "periodUnit": "h" } },
              "doseAndRate": [{ "doseQuantity": { "value": 2, "unit": "tablet" } }]
            }] } },
        { "resource": {
            "resourceType": "MedicationRequest", "status": "active",
            "medicationCodeableConcept": { "text": "oxycodone 5 MG tablet" },
            "dosageInstruction": [{ "text": "Take 1 tablet every 6 hours as needed for pain",
                                    "asNeededBoolean": true,
                                    "timing": { "repeat": { "frequency": 1, "period": 6, "periodUnit": "h" } } }] } },
        { "resource": {
            "resourceType": "MedicationRequest", "status": "stopped",
            "medicationCodeableConcept": { "text": "ibuprofen 200 MG tablet" } } },
        { "resource": { "resourceType": "OperationOutcome" } }
      ]
    }
    """

    private func medicines() throws -> [FHIRMedicationRequest] {
        let bundle = try JSONDecoder().decode(FHIRBundle<FHIRMedicationRequest>.self, from: Data(medicinesJSON.utf8))
        return (bundle.entry ?? []).compactMap(\.resource).filter { $0.resourceType == "MedicationRequest" }
    }

    @Test("Active medicines come in, stopped ones and warnings are left out")
    func keepsOnlyCurrent() throws {
        let draft = FHIRMapper.draft(medicines: try medicines(), visits: [], surgeries: [],
                                     paper: .afterSurgery, now: Date())
        #expect(draft.medicines.count == 2)
        #expect(draft.source == .epic)
        #expect(draft.medicines.allSatisfy { !$0.isConfirmed })     // the patient still checks each one
    }

    @Test("Every 8 hours becomes 3 dose times; as-needed keeps the 6-hour gap")
    func schedule() throws {
        let draft = FHIRMapper.draft(medicines: try medicines(), visits: [], surgeries: [],
                                     paper: .afterSurgery, now: Date())
        let tylenol = try #require(draft.medicines.first { $0.name.hasPrefix("acetaminophen") })
        #expect(tylenol.action == .take)
        #expect(tylenol.timesOfDay == [360, 840, 1320])
        #expect(tylenol.amount == "2 tablet")
        #expect(tylenol.alsoKnownAs.contains("tylenol"))

        let oxycodone = try #require(draft.medicines.first { $0.name.hasPrefix("oxycodone") })
        #expect(oxycodone.action == .takeAsNeeded)
        #expect(oxycodone.minHoursBetween == 6)
        #expect(oxycodone.timesOfDay.isEmpty)
    }

    @Test("Past and cancelled visits are left out; the next surgery sets the date")
    func visitsAndSurgery() throws {
        let now = Date()
        func appointment(_ status: String, inDays days: Int, _ title: String) throws -> FHIRAppointment {
            let start = ISO8601DateFormatter().string(from: now.addingTimeInterval(Double(days) * 86_400))
            let json = """
            { "resourceType": "Appointment", "status": "\(status)", "start": "\(start)",
              "serviceType": [{ "text": "\(title)" }] }
            """
            return try JSONDecoder().decode(FHIRAppointment.self, from: Data(json.utf8))
        }
        let visits = [try appointment("booked", inDays: 14, "Post-op check"),
                      try appointment("booked", inDays: -30, "Old visit"),
                      try appointment("cancelled", inDays: 5, "Cancelled visit")]
        let surgeries = [try appointment("booked", inDays: 7, "Knee replacement")]

        let draft = FHIRMapper.draft(medicines: [], visits: visits, surgeries: surgeries,
                                     paper: .beforeSurgery, now: now)
        #expect(draft.appointments.map(\.title) == ["Post-op check"])
        #expect(draft.procedure == "Knee replacement")
        #expect(draft.surgeryDate != nil)
    }
}
