//
//  MedicineActions.swift
//  Remedy
//
//  saves i've put them away
//

import Foundation
import SwiftData

enum MedicineActions {

    // marks these stops as done
    static func markPutAway(_ medicines: [MedicineInstruction], now: Date, in context: ModelContext) {
        for medicine in medicines {
            medicine.putAwayAt = now
        }
        context.saveNow()
    }

    // undo back to not put away
    static func clearPutAway(_ medicines: [MedicineInstruction], in context: ModelContext) {
        for medicine in medicines {
            medicine.putAwayAt = nil
        }
        context.saveNow()
    }
}
