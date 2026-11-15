//
//  MedicineActions.swift
//  Remedy
//
//  saves medicine edits, i've put them away and the last dose answer
//

import Foundation
import SwiftData

// saves medicine edits and answers about the medicine
enum MedicineActions {

    // marks these stops as done
    static func markPutAway(_ medicines: [MedicineInstruction], now: Date, in context: ModelContext) {
        for medicine in medicines {
            medicine.putAwayAt = now
        }
        context.saveNow()
    }

    // saves the answer to the last dose question
    static func setLastTaken(_ answer: LastDoseAnswer?, on medicine: MedicineInstruction, now: Date, in context: ModelContext) {
        medicine.lastTakenAnswer = answer?.rawValue
        medicine.lastTakenAt = answer == nil ? nil : now
        context.saveNow()
    }

    // undo back to not put away
    static func clearPutAway(_ medicines: [MedicineInstruction], in context: ModelContext) {
        for medicine in medicines {
            medicine.putAwayAt = nil
        }
        context.saveNow()
    }

    // MARK: - Edit, add, delete

    // what the form starts with
    static func draft(for medicine: MedicineInstruction) -> MedicineDraft {
        MedicineDraft(name: medicine.name, amount: medicine.amount, notes: medicine.foodNote,
                      purpose: medicine.action == .takeAsNeeded ? medicine.onlyIf : medicine.reason,
                      action: medicine.action, times: medicine.timesOfDay.sorted(),
                      startDay: medicine.startDay, endDay: medicine.endDay,
                      maxPerDay: medicine.maxPerDay.map(String.init) ?? "",
                      minHours: medicine.minHoursBetween.map(String.init) ?? "")
    }

    // writes the form into the medicine, or into a new one in the plan
    @discardableResult
    static func save(_ draft: MedicineDraft, to medicine: MedicineInstruction?, in plan: CarePlan, now: Date,
                     context: ModelContext) -> MedicineInstruction? {
        guard draft.canSave else { return nil }
        let target: MedicineInstruction
        if let medicine {
            target = medicine
        } else {
            let today = DoseSchedule.today(for: plan, now: now) ?? 0
            target = MedicineInstruction(name: draft.trimmedName, action: draft.action,
                                         paper: today < 0 ? .beforeSurgery : .afterSurgery, quote: "")
            context.insert(target)
            target.plan = plan
            target.isConfirmed = true
        }
        // a changed name must not keep the old brand names
        if target.name != draft.trimmedName, medicine != nil { target.alsoKnownAs = [] }
        target.name = draft.trimmedName
        target.amount = draft.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        target.foodNote = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let purpose = draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.action == .takeAsNeeded { target.onlyIf = purpose } else { target.reason = purpose }
        target.action = draft.action
        target.timesOfDay = draft.usesTimes ? MedicineDraft.cleanTimes(draft.times) : []
        target.startDay = draft.startDay
        target.endDay = draft.endDay
        let asNeeded = draft.action == .takeAsNeeded
        target.maxPerDay = asNeeded ? EditText.number(draft.maxPerDay) : nil
        target.minHoursBetween = asNeeded ? EditText.number(draft.minHours) : nil
        // a paper line changed by hand is marked as the patient's, not the paper's
        if medicine != nil { target.changedByYouAt = now }
        context.saveNow()
        return target
    }

    // after the new line is saved: the stop ends the day before, both lines say who said OK
    static func finishRestart(stop: MedicineInstruction, newLine: MedicineInstruction, who: String, on date: Date,
                              context: ModelContext) {
        guard let surgery = stop.plan?.surgeryDate else { return }
        let restartDay = DayMath.dayOffset(of: date, from: surgery)
        stop.endDay = RestartRule.stopEndDay(restartDay: restartDay)
        let note = RestartRule.note(who: who, dateText: DayMath.shortDate(date))
        stop.restartNote = note
        newLine.restartNote = note
        context.saveNow()
    }

    // removes the medicine and its dose history
    static func delete(_ medicine: MedicineInstruction, in context: ModelContext) {
        context.delete(medicine)
        context.saveNow()
    }
}
