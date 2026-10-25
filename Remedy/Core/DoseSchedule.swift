//
//  DoseSchedule.swift
//  Remedy
//
//  works out which doses are due missed or next
//

import Foundation
import SwiftData

// before or after surgery - most of the app depends on this
enum SurgeryPhase: Equatable {
    case beforeSurgery      // Day -1 and earlier
    case surgeryDay         // Day 0
    case afterSurgery       // Day +1 and later

    // phase for a plan day
    static func forDay(_ day: Int) -> SurgeryPhase {
        if day < 0 { return .beforeSurgery }
        if day == 0 { return .surgeryDay }
        return .afterSurgery
    }
}

// morning afternoon or evening
enum DayPeriod: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

// for on the border between morning/afternoon or afternoon/evening
    static func forMinute(_ minuteOfDay: Int) -> DayPeriod {
        if minuteOfDay < 12 * 60 { return .morning }
        if minuteOfDay < 17 * 60 { return .afternoon }
        return .evening
    }
}

// enum for where user dose is rn
enum DoseSlotState: Equatable {
    case upcoming   // later today
    case due        // it's time now (30 min before to 60 min after)
    case taken
    case skipped
    case missed     // more than 60 min late and not logged
}

// one dose time for one medicine
struct DoseSlot: Identifiable { // for swiftdata

    // medicine and time
    struct ID: Hashable {
        let medicine: PersistentIdentifier
        let scheduledFor: Date
    }

    let medicine: MedicineInstruction
    let minute: Int
    let scheduledFor: Date
    let state: DoseSlotState
    let log: DoseLog?
    
    var id: ID { ID(medicine: medicine.persistentModelID, scheduledFor: scheduledFor) }
}

// for only when needed - ensures within limits
struct AsNeededStatus {
    let takenToday: Int
    let lastTaken: Date?
    let nextAllowed: Date?
    let reachedMax: Bool
    var canTakeNow: Bool { nextAllowed == nil && !reachedMax }
}

// MAIN LOGIC for medicines
enum DoseSchedule {

// time period ot take medicine in @nikhil lmk if we should change
    
    static let dueMinutesBefore = 30
    static let missedMinutesAfter = 60

   // what day is rn
    static func today(for plan: CarePlan, now: Date) -> Int? {
        guard let surgeryDate = plan.surgeryDate else { return nil }
        return DayMath.dayOffset(of: now, from: surgeryDate)
    }

   // determines soecifics for today
    static func isActive(startDay: Int?, endDay: Int?, on day: Int) -> Bool {
        let start = startDay ?? Int.min
        let end = endDay ?? Int.max
        return day >= start && day <= end
    }

    static func isActive(_ medicine: MedicineInstruction, on day: Int) -> Bool {
        isActive(startDay: medicine.startDay, endDay: medicine.endDay, on: day)
    }

    // for rules doctor writes that dont say when they start
    static func startDay(of rule: CareRule) -> Int {
        rule.startDay ?? (rule.paper == .afterSurgery ? 0 : Int.min)
    }

// for pre-op period
    static func isActive(_ rule: CareRule, on day: Int) -> Bool {
        isActive(startDay: startDay(of: rule), endDay: rule.endDay, on: day)
    }

// for recovery period
    static func isActive(_ goal: DailyGoal, on day: Int) -> Bool {
        isActive(startDay: goal.startDay ?? 1, endDay: goal.endDay, on: day)
    }

   // all the medicines for today
    static func slots(onDay day: Int, plan: CarePlan, now: Date) -> [DoseSlot] {
        guard let surgeryDate = plan.surgeryDate else { return [] }

        var result: [DoseSlot] = []
        for medicine in plan.medicines where medicine.action == .take && medicine.isConfirmed && isActive(medicine, on: day) {
            for minute in medicine.timesOfDay.sorted() {
                let time = DayMath.date(forDay: day, minute: minute, from: surgeryDate)
                let log = savedLog(for: medicine, at: time)
                let slot = DoseSlot(
                    medicine: medicine,
                    minute: minute,
                    scheduledFor: time,
                    state: state(at: time, log: log, now: now),
                    log: log
                )
                result.append(slot)
            }
        }
        // sort by early to late if same time keep order from teh paper
        return result.sorted { $0.minute < $1.minute }
    }

    // saved patietn log
    static func savedLog(for medicine: MedicineInstruction, at time: Date) -> DoseLog? {
        medicine.doseLogs.first { abs($0.scheduledFor.timeIntervalSince(time)) < 60 }
    }

    
    // due missed taken or upcoming
    static func state(at time: Date, log: DoseLog?, now: Date) -> DoseSlotState {
        if let log {
            return log.status == .taken ? .taken : .skipped
        }
        let minutesLate = Int(now.timeIntervalSince(time) / 60)
        if minutesLate > missedMinutesAfter { return .missed }
        if minutesLate >= -dueMinutesBefore { return .due }
        return .upcoming
    }

  // for only when needed
    static func asNeededStatus(for medicine: MedicineInstruction, now: Date) -> AsNeededStatus {
        let todayStart = DayMath.calendar.startOfDay(for: now)

        // log
        let taken = medicine.doseLogs
            .filter { $0.status == .taken }
            .sorted { $0.loggedAt > $1.loggedAt }
        let todayCount = taken.filter { $0.loggedAt >= todayStart }.count
        let last = taken.first?.loggedAt

        // hours between
        var next: Date? = nil
        if let last, let hours = medicine.minHoursBetween {
            let allowed = last.addingTimeInterval(TimeInterval(hours * 3600))
            if allowed > now { next = allowed }
        }

        // max/day
        let reachedMax = medicine.maxPerDay.map { todayCount >= $0 } ?? false

        return AsNeededStatus(takenToday: todayCount, lastTaken: last, nextAllowed: next, reachedMax: reachedMax)
    }

    // for daily goals
    static func goalCount(_ goal: DailyGoal, now: Date) -> Int {
        let todayStart = DayMath.calendar.startOfDay(for: now)
        return goal.logs.filter { $0.loggedAt >= todayStart && $0.loggedAt <= now }.count
    }
}
