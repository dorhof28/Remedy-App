//
//  SampleFHIR.swift
//  Remedy
//
//  DEMO ONLY a made up mychart record in real fhir json for the video
//

import Foundation

enum SampleFHIR {

    // runs the made up record through the same mapper as the real one
    static func draft(paper: PaperKind, now: Date) -> DraftPlan {
        let decoder = JSONDecoder()
        let medicines = (try? decoder.decode([FHIRMedicationRequest].self, from: Data(medicinesJSON.utf8))) ?? []
        let visits = (try? decoder.decode([FHIRAppointment].self, from: Data(visitsJSON(now: now).utf8))) ?? []
        let surgeries = (try? decoder.decode([FHIRAppointment].self, from: Data(surgeryJSON(now: now).utf8))) ?? []
        var draft = FHIRMapper.draft(medicines: medicines, visits: visits, surgeries: surgeries, paper: paper, now: now)
        draft.readBy = "Sample MyChart record (demo)"
        return draft
    }

    // the dates move with today so the demo never goes stale
    private static func iso(_ days: Int, hour: Int, from now: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now
        let time = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        return ISO8601DateFormatter().string(from: time)
    }

    private static let medicinesJSON = """
    [
      {"resourceType": "MedicationRequest", "status": "active",
       "medicationReference": {"display": "cephalexin 500 MG capsule"},
       "dosageInstruction": [{"text": "Take 1 capsule by mouth 4 times a day for 7 days",
         "timing": {"repeat": {"frequency": 4, "period": 1, "periodUnit": "d"}},
         "doseAndRate": [{"doseQuantity": {"value": 1, "unit": "capsule"}}]}]},
      {"resourceType": "MedicationRequest", "status": "active",
       "medicationReference": {"display": "oxyCODONE-acetaminophen (PERCOCET) 5-325 MG tablet"},
       "dosageInstruction": [{"text": "Take 1 tablet by mouth every 6 hours as needed for severe pain",
         "asNeededBoolean": true,
         "timing": {"repeat": {"frequency": 1, "period": 6, "periodUnit": "h"}},
         "doseAndRate": [{"doseQuantity": {"value": 1, "unit": "tablet"}}]}]},
      {"resourceType": "MedicationRequest", "status": "active",
       "medicationReference": {"display": "aspirin 81 MG chewable tablet"},
       "dosageInstruction": [{"text": "Take 1 tablet by mouth twice a day to prevent blood clots",
         "timing": {"repeat": {"frequency": 2, "period": 1, "periodUnit": "d"}},
         "doseAndRate": [{"doseQuantity": {"value": 1, "unit": "tablet"}}]}]},
      {"resourceType": "MedicationRequest", "status": "on-hold",
       "medicationReference": {"display": "ibuprofen (MOTRIN) 600 MG tablet"},
       "dosageInstruction": [{"text": "Hold until your surgeon says it is OK"}]}
    ]
    """

    private static func visitsJSON(now: Date) -> String {
        """
        [
          {"resourceType": "Appointment", "status": "booked", "start": "\(iso(2, hour: 10, from: now))",
           "serviceType": [{"text": "Pre-op testing"}],
           "patientInstruction": "Bring your medicine list and a photo ID.",
           "participant": [{"actor": {"reference": "Location/1", "display": "Valley Hospital Lab"}}]},
          {"resourceType": "Appointment", "status": "booked", "start": "\(iso(19, hour: 14, from: now))",
           "serviceType": [{"text": "Check-up with your surgeon"}],
           "participant": [{"actor": {"reference": "Practitioner/1", "display": "Dr. Patel"}},
                           {"actor": {"reference": "Location/2", "display": "Orthopedic Office"}}]}
        ]
        """
    }

    private static func surgeryJSON(now: Date) -> String {
        """
        [
          {"resourceType": "Appointment", "status": "booked", "start": "\(iso(5, hour: 7, from: now))",
           "serviceType": [{"text": "Right knee replacement"}]}
        ]
        """
    }
}
