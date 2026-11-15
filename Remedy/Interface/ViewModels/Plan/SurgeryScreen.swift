//
//  SurgeryScreen.swift
//  Remedy
//
//  words for your surgery (screen 49) and choose hospital (screen 50)
//

import Foundation

// the your surgery page: name, date, hospital and times
struct SurgeryScreen {
    let plan: CarePlan
    let now: Date

    let title = "Your Surgery"
    let timesTitle = "Times"
    let footer = "Your arrival time sets when to stop eating and drinking. Your papers filled these in; you can change them."
    let notSet = "Add"

    // which row is being changed
    enum Field: String, Identifiable {
        case procedure, date, whereToGo, arrival, start, home
        var id: String { rawValue }
    }

    var procedure: String { plan.procedure }
    var dateText: String {
        plan.surgeryDate.map { $0.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()) } ?? notSet
    }
    var hospital: String { plan.hospitalName ?? "" }
    var hospitalSubtitle: String { hospital.isEmpty ? (plan.hospitalAddress ?? "") : hospital }
    var whereToGo: String { plan.hospitalWhereToGo ?? "" }

    // the papers' arrival time when the patient set none
    var arrival: Date? { plan.arrivalTime ?? DayChecklist.arrival(for: plan) }
    var arrivalText: String { arrival.map { DayMath.timeText(of: $0) } ?? notSet }
    var startText: String { plan.surgeryStartTime.map { "About " + DayMath.timeText(of: $0) } ?? notSet }
    var homeText: String { plan.dischargeDate.map { DayMath.shortDate($0) } ?? notSet }

    func fieldTitle(_ field: Field) -> String {
        switch field {
        case .procedure: return "Surgery"
        case .date: return "Date"
        case .whereToGo: return "Where to go"
        case .arrival: return "Arrive at"
        case .start: return "Surgery starts"
        case .home: return "Home from hospital"
        }
    }

    func fieldPrompt(_ field: Field) -> String {
        switch field {
        case .procedure: return "Like right knee replacement"
        case .whereToGo: return "Like main entrance, floor 2"
        default: return ""
        }
    }
}

// the hospital search page
struct HospitalSearchScreen {
    let plan: CarePlan

    let title = "Hospital"
    let prompt = "Search by name"
    let fromPapersTitle = "From your papers"
    let otherTitle = "Other matches"
    let typeAddressButton = "Type an Address Instead"

    // the hospital from the papers comes first
    var fromPapers: (name: String, address: String)? {
        guard let name = plan.hospitalName, !name.isEmpty else { return nil }
        return (name, plan.hospitalAddress ?? "")
    }
}
