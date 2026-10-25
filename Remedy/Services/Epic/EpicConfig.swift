//
//  EpicConfig.swift
//  Remedy
//
//  epic sandbox settings
//

import Foundation

enum EpicConfig {

    // from fhir.epic.com
    static let clientID = "41e976be-bf8e-46ba-bce1-bed34bb02912"

    // epic's sandbox
    static let fhirBase = URL(string: "https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4")!

    static let callbackScheme = "remedy"
    static let redirectURI = "remedy://oauth/callback"

    // only what we need medicines and visits
    static let scopes = "openid fhirUser launch/patient patient/MedicationRequest.read patient/Appointment.read"

    // the MyChart button only shows once the client ID is filled in
    static var isSetUp: Bool { !clientID.hasPrefix("PASTE") && !clientID.isEmpty }
}
