//
//  Enums.swift
//  Remedy
//
//  shared enums for the models
//

import Foundation

// before or after surgery papers
enum PaperKind: String, Codable, CaseIterable {
    case beforeSurgery
    case afterSurgery
}
// who gave the patient a paper
enum PaperSource: String, Codable, CaseIterable {
    case surgeryTeam        // surgeon's office, hospital, pre-admission testing, anesthesia
    case specialist
    case primaryCare
    case hospitalRecord     // MyChart or Health list
    case other
}
// what a specialist looks after, only used when the source is specialist
enum PaperField: String, Codable, CaseIterable {
    case heart
    case kidney
    case blood
    case diabetes
    case lungs
    case other
}
// where the plan came from
enum PlanSource: String, Codable, CaseIterable {
    case scan
    case epic
    case manual
    case appleHealth    // Health Records in the Health app
}
// take as needed stop or ok
enum MedicineAction: String, Codable, CaseIterable {
    case take
    case takeAsNeeded
    case stop
    case okToTake
}

// taken or skipped
enum DoseStatus: String, Codable, CaseIterable {
    case taken
    case skipped
}

// care team pharmacy or family
enum ContactRole: String, Codable, CaseIterable {
    case careTeam     
    case pharmacy
    case family
}
