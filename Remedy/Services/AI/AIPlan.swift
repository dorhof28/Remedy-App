//
//  AIPlan.swift
//  Remedy
//
//  the shape the ai has to answer in
//

import Foundation
import FoundationModels

// everything from one piece of the papers
@Generable
nonisolated struct AIPlan {
    @Guide(description: "The operation, like \"Knee replacement\". Empty if not written.")
    var procedure: String
    @Guide(description: "The date of the operation itself, exactly as written, only when the papers say it is the surgery date. Not the date of this visit, a consultation, pre-op testing, the print date or any appointment. Empty if unsure.")
    var surgeryDate: String
    var medicines: [AIMedicine]
    var rules: [AIRule]
    var tasks: [AITask]
    var visits: [AIVisit]
    var contacts: [AIContact]
}

// what to do with a medicine
@Generable
nonisolated enum AIMedicineAction {
    case take           // on a schedule every day
    case takeAsNeeded   // only when needed, like pain medicine
    case stop           // stop or don't take
    case okToTake       // the papers say it's OK
}

// one medicine
@Generable
nonisolated struct AIMedicine {
    @Guide(description: "The exact words from the papers, word for word. For an item in a list, the heading and the item")
    var quote: String
    @Guide(description: "The medicine or group name as written, like \"Aspirin 325 mg\" or \"Vitamins and supplements\"")
    var name: String
    @Guide(description: "Other names for it written on the papers (brand or generic), lower case")
    var otherNames: [String]
    @Guide(description: "true for a group, like \"any other NSAID\" or \"all supplements\"")
    var isGroup: Bool
    var action: AIMedicineAction
    @Guide(description: "First day it applies. Surgery day is 0, the day before is -1, the day after is 1")
    var startDay: Int?
    @Guide(description: "Last day it applies, counted the same way")
    var endDay: Int?
    @Guide(description: "Strength of one pill, like \"500 mg\"")
    var strength: String
    @Guide(description: "How many each time, like \"2 tablets\"")
    var amount: String
    @Guide(description: "Clock times only if printed, as HH:mm in 24 hours")
    var clockTimes: [String]
    @Guide(description: "Times a day, like 2 for \"twice a day\"")
    var timesPerDay: Int?
    @Guide(description: "Hours between doses, like 8 for \"every 8 hours\"")
    var everyHours: Int?
    @Guide(description: "Most doses allowed in one day")
    var maxPerDay: Int?
    @Guide(description: "Food note, like \"with food\"")
    var foodNote: String
    @Guide(description: "When to take it, for as-needed medicines, like \"severe pain\"")
    var onlyIf: String
    @Guide(description: "Why, if the papers say")
    var reason: String
    @Guide(description: "An exception, if the papers give one")
    var exception: String
}

// one rule
@Generable
nonisolated struct AIRule {
    @Guide(description: "The exact sentence from the papers, word for word")
    var quote: String
    @Guide(description: "Short title, like \"No driving\" or \"Showers\"")
    var title: String
    @Guide(description: "true if it says you may, false if it says don't")
    var isAllowed: Bool
    @Guide(description: "Only while something is true, like \"While you take oxycodone\"")
    var condition: String
    var startDay: Int?
    var endDay: Int?
}

// one to do
@Generable
nonisolated struct AITask {
    @Guide(description: "The exact sentence from the papers, word for word")
    var quote: String
    @Guide(description: "Something the patient must do once, like \"Bring your inhalers to the hospital\"")
    var title: String
    @Guide(description: "Day it must be done by, counted from surgery")
    var dueDay: Int?
}

// one visit
@Generable
nonisolated struct AIVisit {
    @Guide(description: "The exact sentence from the papers, word for word")
    var quote: String
    @Guide(description: "Like \"Check-up with your surgeon\" or \"Physical therapy\"")
    var title: String
    var doctor: String
    var place: String
    var phone: String
    var purpose: String
    @Guide(description: "The date exactly as written, like \"November 2, 2026\". Empty if not printed.")
    var dateText: String
    @Guide(description: "The time exactly as written, like \"2:30 PM\". Empty if not printed.")
    var timeText: String
    @Guide(description: "If there is no date: which day after surgery, like 14 for \"in 2 weeks\"")
    var dayFromSurgery: Int?
}

// one phone number
@Generable
nonisolated struct AIContact {
    @Guide(description: "Like \"Surgeon's office\" or \"Hospital pharmacy\"")
    var name: String
    @Guide(description: "What to call them about")
    var detail: String
    var phone: String
    @Guide(description: "true for a pharmacy")
    var isPharmacy: Bool
}

// MARK: - Reading the same shape from JSON (Gemini answers in JSON)

// swift writes the JSON reading for us
nonisolated extension AIPlan: Decodable {}
nonisolated extension AIMedicine: Decodable {}
nonisolated extension AIRule: Decodable {}
nonisolated extension AITask: Decodable {}
nonisolated extension AIVisit: Decodable {}
nonisolated extension AIContact: Decodable {}

// action comes as plain text
nonisolated extension AIMedicineAction: Decodable {
    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        switch text {
        case "take": self = .take
        case "takeAsNeeded": self = .takeAsNeeded
        case "stop": self = .stop
        case "okToTake": self = .okToTake
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown medicine action: \(text)"))
        }
    }
}
