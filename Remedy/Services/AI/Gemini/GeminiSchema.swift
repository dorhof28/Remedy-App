//
//  GeminiSchema.swift
//  Remedy
//
//  aiplan as a gemini json schema
//

import Foundation

enum GeminiSchema {

    static let plan: [String: Any] = object([
        ("procedure", text("The operation, like \"Knee replacement\". Empty if not written.")),
        ("surgeryDate", text("The date of the operation itself, exactly as written, only when the papers say it is the surgery date. Not the date of this visit, a consultation, pre-op testing, the print date or any appointment. Empty if unsure.")),
        ("medicines", list(medicine)),
        ("rules", list(rule)),
        ("tasks", list(task)),
        ("visits", list(visit)),
        ("contacts", list(contact)),
    ])

    private static let quote = text("The exact words from the papers, word for word")

    private static let medicine: [String: Any] = object([
        ("quote", text("The exact words from the papers, word for word. For an item in a list, the heading and the item")),
        ("name", text("The medicine or group name as written")),
        ("otherNames", list(text("Another name for it written on the papers, lower case"))),
        ("isGroup", yesNo("true for a group, like \"any other NSAID\"")),
        ("action", choice(["take", "takeAsNeeded", "stop", "okToTake"])),
        ("startDay", day("First day it applies. Surgery day is 0, the day before is -1, the day after is 1")),
        ("endDay", day("Last day it applies, counted the same way")),
        ("strength", text("Strength of one pill, like \"500 mg\"")),
        ("amount", text("How many each time, like \"2 tablets\"")),
        ("clockTimes", list(text("A clock time only if printed, as HH:mm in 24 hours"))),
        ("timesPerDay", day("Times a day, like 2 for \"twice a day\"")),
        ("everyHours", day("Hours between doses, like 8 for \"every 8 hours\"")),
        ("maxPerDay", day("Most doses allowed in one day")),
        ("foodNote", text("Food note, like \"with food\"")),
        ("onlyIf", text("When to take it, for as-needed medicines")),
        ("reason", text("Why, if the papers say")),
        ("exception", text("An exception, if the papers give one")),
    ])

    private static let rule: [String: Any] = object([
        ("quote", quote),
        ("title", text("Short title, like \"No driving\" or \"Showers\"")),
        ("isAllowed", yesNo("true if it says you may, false if it says don't")),
        ("condition", text("Only while something is true, like \"While you take oxycodone\"")),
        ("startDay", day("First day it applies, counted from surgery")),
        ("endDay", day("Last day it applies, counted from surgery")),
    ])

    private static let task: [String: Any] = object([
        ("quote", quote),
        ("title", text("Something the patient must do once")),
        ("dueDay", day("Day it must be done by, counted from surgery")),
    ])

    private static let visit: [String: Any] = object([
        ("quote", quote),
        ("title", text("Like \"Check-up with your surgeon\"")),
        ("doctor", text("")),
        ("place", text("")),
        ("phone", text("")),
        ("purpose", text("")),
        ("dateText", text("The date exactly as written. Empty if not printed.")),
        ("timeText", text("The time exactly as written. Empty if not printed.")),
        ("dayFromSurgery", day("If there is no date: which day after surgery, like 14 for \"in 2 weeks\"")),
    ])

    private static let contact: [String: Any] = object([
        ("name", text("Like \"Surgeon's office\"")),
        ("detail", text("What to call them about")),
        ("phone", text("")),
        ("isPharmacy", yesNo("true for a pharmacy")),
    ])

    // MARK: - Building blocks

    // every field is required "day" fields may be null
    private static func object(_ fields: [(String, [String: Any])]) -> [String: Any] {
        [
            "type": "OBJECT",
            "properties": Dictionary(uniqueKeysWithValues: fields),
            "required": fields.map(\.0),
            "propertyOrdering": fields.map(\.0),
        ]
    }

    private static func text(_ description: String) -> [String: Any] {
        description.isEmpty ? ["type": "STRING"] : ["type": "STRING", "description": description]
    }

    private static func yesNo(_ description: String) -> [String: Any] {
        ["type": "BOOLEAN", "description": description]
    }

    // a whole number that can be left out
    private static func day(_ description: String) -> [String: Any] {
        ["type": "INTEGER", "nullable": true, "description": description]
    }

    private static func choice(_ options: [String]) -> [String: Any] {
        ["type": "STRING", "enum": options]
    }

    private static func list(_ item: [String: Any]) -> [String: Any] {
        ["type": "ARRAY", "items": item]
    }
}
