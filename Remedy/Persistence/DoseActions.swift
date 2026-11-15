//
//  DoseActions.swift
//  Remedy
//
//  saves user actions for medicines
//

import Foundation
import SwiftData

// allows undo
struct DoseUndo {
    let log: DoseLog
    let previousStatus: DoseStatus?
}

// logs doses, each log returns an undo
enum DoseActions {

    // saves a taken or skipped dose
    @discardableResult
    static func log(_ medicine: MedicineInstruction,
                    scheduledFor time: Date,
                    as status: DoseStatus,
                    now: Date,
                    in context: ModelContext) -> DoseUndo {

        if let existing = DoseSchedule.savedLog(for: medicine, at: time) {
            let undo = DoseUndo(log: existing, previousStatus: existing.status)
            existing.status = status
            existing.loggedAt = now
            context.saveNow()
            return undo
        }

        let log = DoseLog(scheduledFor: time, status: status, loggedAt: now)
        context.insert(log)
        log.medicine = medicine
        context.saveNow()
        return DoseUndo(log: log, previousStatus: nil)
    }

    // saves an only when needed dose
    @discardableResult
    static func logAsNeeded(_ medicine: MedicineInstruction, now: Date, in context: ModelContext) -> DoseUndo {
        let log = DoseLog(scheduledFor: now, status: .taken, loggedAt: now)
        context.insert(log)
        log.medicine = medicine
        context.saveNow()
        return DoseUndo(log: log, previousStatus: nil)
    }

    // 94, a dose answer or time changed in the dose log, marked changed by you
    @discardableResult
    static func change(_ medicine: MedicineInstruction, scheduledFor time: Date, to status: DoseStatus,
                       takenAt: Date, in context: ModelContext) -> DoseLog {
        let log = DoseSchedule.savedLog(for: medicine, at: time) ?? {
            let new = DoseLog(scheduledFor: time, status: status, loggedAt: takenAt)
            context.insert(new)
            new.medicine = medicine
            return new
        }()
        log.status = status
        log.loggedAt = status == .taken ? takenAt : log.loggedAt
        log.changedByYou = true
        context.saveNow()
        return log
    }

    // takes a saved dose back off
    static func remove(_ log: DoseLog, in context: ModelContext) {
        context.delete(log)
        context.saveNow()
    }

    // puts a dose back how it was
    static func undo(_ undo: DoseUndo, in context: ModelContext) {
        if let previous = undo.previousStatus {
            undo.log.status = previous
        } else {
            context.delete(undo.log)
        }
        context.saveNow()
    }
}
