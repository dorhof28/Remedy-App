//
//  MedicineInstruction.swift
//  Remedy
//
//  one medicine and what to do with it
//

import Foundation
import SwiftData

// one medicine line from one paper: take, stop, as needed or ok to take, with its days and quote
@Model
final class MedicineInstruction {

    var name: String = ""
    var alsoKnownAs: [String] = []
    // true for a rule but not one pill
    var isGroup: Bool = false
    // what to do
    var actionRaw: String = MedicineAction.take.rawValue

    var startDay: Int?
    var endDay: Int?
    
    // how much a dose is ie
    var strength: String = ""
    var amount: String = ""

    var timesOfDay: [Int] = []
    var foodNote: String = ""

    // ie
    var onlyIf: String = ""
    var minHoursBetween: Int?
    var maxPerDay: Int?
    // the hospital's last dose from the discharge paper
    var lastGivenAt: Date?
    // the paper's dose time the patient said the hospital already gave, when the paper's time was unreadable
    var hospitalDoseAt: Date?

    var reason: String = ""
    var exception: String = ""
    
    var pillShape: String = ""
    var pillColor: String = ""
    
    // line from the paper
    var quote: String = ""
    var quotePage: Int?
    var paperRaw: String = PaperKind.afterSurgery.rawValue

    var isConfirmed: Bool = true

    // when the patient tapped "I've put them away" for a stop
    var putAwayAt: Date?
    // the optional "did you take any today" answer on a stop day: yes or no
    var lastTakenAnswer: String?
    var lastTakenAt: Date?
    var createdAt: Date = Date()
    // set when the patient changes it by hand, so the detail says "Changed by you"
    var changedByYouAt: Date?
    // "Restarted, said OK by surgeon's office, Mon, Nov 23" after a restart (screen 36)
    var restartNote: String?

    var paperID: UUID?      // the Paper record it came from
    var plan: CarePlan?

    // every time sm took or skipped a dose of this
    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medicine)
    var doseLogs: [DoseLog] = []

    init(name: String, action: MedicineAction, paper: PaperKind, quote: String) {
        self.name = name
        self.actionRaw = action.rawValue
        self.paperRaw = paper.rawValue
        self.quote = quote
    }

    var action: MedicineAction {
        get { MedicineAction(rawValue: actionRaw) ?? .take }
        set { actionRaw = newValue.rawValue }
    }

    var paper: PaperKind {
        get { PaperKind(rawValue: paperRaw) ?? .afterSurgery }
        set { paperRaw = newValue.rawValue }
    }
}
