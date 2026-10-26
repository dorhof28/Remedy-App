//
//  FHIRMapper.swift
//  Remedy
//
//  turns hospital records into a draft plan
//

import Foundation

enum FHIRMapper {

    // hospital records to a draft
    static func draft(medicines: [FHIRMedicationRequest], visits: [FHIRAppointment],
                      surgeries: [FHIRAppointment], paper: PaperKind, now: Date) -> DraftPlan {
        var draft = DraftPlan(paper: paper)
        draft.source = .epic

        // the next surgery sets Day 0
        if let surgery = upcoming(surgeries, now: now).first {
            draft.surgeryDate = surgery.start.flatMap(date(from:))
            draft.procedure = surgery.serviceType?.first?.bestText ?? surgery.description ?? ""
        }
        draft.medicines = medicines.compactMap { medicine($0) }
        draft.appointments = upcoming(visits, now: now).compactMap { visit($0) }
        return draft
    }

    // MARK: - Medicines

    // one order to a draft medicine
    static func medicine(_ order: FHIRMedicationRequest) -> DraftMedicine? {
        let rawName = (order.medicationCodeableConcept?.bestText ?? order.medicationReference?.display ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return nil }
        // "aspirin 81 MG chewable tablet" to aspirin and 81 mg
        let cleaned = MedicineNameCleaner.clean(rawName)
        let name = cleaned.name

        let dosage = order.firstDosage
        let action: MedicineAction
        var reason = order.reasonCode?.first?.bestText ?? ""
        switch order.status {
        case "active", nil:
            action = dosage?.asNeededBoolean == true ? .takeAsNeeded : .take
        case "on-hold":
            action = .stop
            reason = "On hold in your hospital record."
        default:
            return nil          // stopped, completed, cancelled: not a current medicine
        }

        // "3 times per 1 day" or "1 time per 8 hours"
        let schedule = dosage?.timing?.repeat
        var timesPerDay: Int?
        var everyHours: Int?
        if let frequency = schedule?.frequency, let period = schedule?.period, period > 0 {
            switch schedule?.periodUnit ?? schedule?.periodUnits {
            case "d": timesPerDay = Int((Double(frequency) / period).rounded())
            case "h": everyHours = frequency == 1 ? Int(period) : nil
            default: break
            }
        }

        return DraftMedicine(
            name: name,
            alsoKnownAs: Array(Set(cleaned.otherNames + otherNames(in: rawName))).filter { $0 != name.lowercased() }.sorted(),
            action: action,
            strength: cleaned.strength,
            amount: amountText(dosage?.doseAndRate?.first?.doseQuantity),
            timesOfDay: action == .take
                ? AIPlanConverter.doseTimes(clockTimes: schedule?.timeOfDay ?? [], timesPerDay: timesPerDay, everyHours: everyHours)
                : [],
            minHoursBetween: action == .takeAsNeeded ? everyHours : nil,
            reason: reason,
            // the record's own words shown under the item like a quote from paper
            quote: dosage?.text ?? dosage?.patientInstruction ?? rawName)
    }

    // so Ask can match "Can I take Tylenol?"
    static func otherNames(in name: String) -> [String] {
        var names: [String] = []
        if let first = name.split(separator: " ").first {
            names.append(first.lowercased())
        }
        if let open = name.firstIndex(of: "("), let close = name[open...].firstIndex(of: ")") {
            let brand = name[name.index(after: open)..<close].lowercased()
            if !brand.isEmpty && !names.contains(brand) { names.append(brand) }
        }
        return names
    }

    private static func amountText(_ quantity: FHIRMedicationRequest.Quantity?) -> String {
        guard let value = quantity?.value else { return "" }
        let number = value == value.rounded() ? String(Int(value)) : String(value)
        return [number, quantity?.unit ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - Visits

    // one appointment to a draft visit
    static func visit(_ appointment: FHIRAppointment) -> DraftAppointment? {
        guard let when = appointment.start.flatMap(date(from:)) else { return nil }
        let title = appointment.serviceType?.first?.bestText ?? appointment.description ?? "Appointment"
        let people = appointment.participant ?? []
        let doctor = people.first { $0.actor?.reference?.hasPrefix("Practitioner") == true }?.actor?.display ?? ""
        let place = people.first { $0.actor?.reference?.hasPrefix("Location") == true }?.actor?.display ?? ""
        let purpose = appointment.description == title ? "" : (appointment.description ?? "")
        let quote = [appointment.patientInstruction, appointment.comment, appointment.description]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? title

        return DraftAppointment(title: title, date: when, doctor: doctor, place: place,
                                purpose: purpose, quote: quote)
    }

    // booked visits from today on soonest first
    static func upcoming(_ appointments: [FHIRAppointment], now: Date) -> [FHIRAppointment] {
        let today = Calendar.current.startOfDay(for: now)
        let skipped: Set<String> = ["cancelled", "noshow", "entered-in-error", "fulfilled"]
        return appointments
            .filter { !skipped.contains($0.status ?? "") }
            .compactMap { appointment in appointment.start.flatMap(date(from:)).map { (appointment, $0) } }
            .filter { $0.1 >= today }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    // FHIR dates "2026-11-02T14:30:00Z" sometimes with fractions of a second
    static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
}
