//
//  DoseSchedule.swift
//  Remedy
//
//  works out which doses are due missed or next
//

import Foundation

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

// one dose time for one medicine, persistence names the saved kind DoseSlot
struct DoseSlotOf<Medicine: MedicineFacts>: Identifiable {

    // medicine and time
    struct ID: Hashable {
        let medicine: Medicine.LineID
        let scheduledFor: Date
    }

    let medicine: Medicine
    let minute: Int
    let scheduledFor: Date
    let state: DoseSlotState
    let log: Medicine.Log?
    // the hospital already gave this dose, counts as taken and is never reminded
    var givenInHospital = false

    var id: ID { ID(medicine: medicine.lineID, scheduledFor: scheduledFor) }
}

// lines another paper replaced, only on the days it covers, persistence names the saved kind SkippedLines
struct SkippedLinesOf<LineID: Hashable> {
    var days: [LineID: [DayRange]] = [:]

    // true when the medicine's line is followed on that day
    func contains(_ medicine: LineID, onDay day: Int) -> Bool {
        days[medicine]?.contains { $0.contains(day) } ?? false
    }
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
    static func today(for plan: some PlanFacts, now: Date) -> Int? {
        guard let surgeryDate = plan.surgeryDate else { return nil }
        return DayMath.dayOffset(of: now, from: surgeryDate)
    }

   // determines soecifics for today
    static func isActive(startDay: Int?, endDay: Int?, on day: Int) -> Bool {
        let start = startDay ?? Int.min
        let end = endDay ?? Int.max
        return day >= start && day <= end
    }

    // true when the day is between the start and end days, open ends count as always
    static func isActive(_ medicine: some MedicineFacts, on day: Int) -> Bool {
        isActive(startDay: medicine.startDay, endDay: medicine.endDay, on: day)
    }

    // for rules doctor writes that dont say when they start
    static func startDay(of rule: some RuleFacts) -> Int {
        rule.startDay ?? (rule.paper == .afterSurgery ? 0 : Int.min)
    }

// for pre-op period
    static func isActive(_ rule: some RuleFacts, on day: Int) -> Bool {
        isActive(startDay: startDay(of: rule), endDay: rule.endDay, on: day)
    }

// for recovery period, goals with no start day start the day after surgery
    static func isGoalActive(startDay: Int?, endDay: Int?, on day: Int) -> Bool {
        isActive(startDay: startDay ?? 1, endDay: endDay, on: day)
    }

   // all the medicines for today
    static func slots<Plan: PlanFacts>(onDay day: Int, plan: Plan, now: Date,
                                       skipped: SkippedLinesOf<Plan.Medicine.LineID>) -> [DoseSlotOf<Plan.Medicine>] {
        guard let surgeryDate = plan.surgeryDate else { return [] }

        // replaced lines have no doses on the replaced days
        var result: [DoseSlotOf<Plan.Medicine>] = []
        for medicine in plan.medicines where medicine.action == .take && medicine.isConfirmed
            && !skipped.contains(medicine.lineID, onDay: day) && isActive(medicine, on: day) {
            let hospital = hospitalDose(for: medicine, onDay: day, from: surgeryDate)
            for time in doseTimes(for: medicine, onDay: day, from: surgeryDate) {
                let log = savedLog(for: medicine, at: time)
                let fromHospital = log == nil && time == hospital
                let slot = DoseSlotOf(
                    medicine: medicine,
                    minute: DayMath.minuteOfDay(time),
                    scheduledFor: time,
                    state: fromHospital ? .taken : state(at: time, log: log, now: now),
                    log: log,
                    givenInHospital: fromHospital
                )
                result.append(slot)
            }
        }
        // sort by early to late if same time keep order from teh paper
        return result.sorted { $0.minute < $1.minute }
    }

    // first home dose is the hospital's last one plus the gap from the paper
    static func firstHomeDose(for medicine: some MedicineFacts) -> Date? {
        guard let given = medicine.lastGivenAt, let hours = medicine.minHoursBetween, hours > 0 else { return nil }
        return given.addingTimeInterval(TimeInterval(hours * 3600))
    }

    // the paper's times for one day moved to start from the hospital dose
    static func doseTimes(for medicine: some MedicineFacts, onDay day: Int, from surgeryDate: Date) -> [Date] {
        let times = medicine.timesOfDay.sorted().map { DayMath.date(forDay: day, minute: $0, from: surgeryDate) }
        guard !times.isEmpty, let first = firstHomeDose(for: medicine), let given = medicine.lastGivenAt,
              let hours = medicine.minHoursBetween else { return times }
        let calendar = DayMath.calendar
        let dayStart = DayMath.date(forDay: day, from: surgeryDate)

        // no paper time before the first home dose or within the gap after it
        let gapAfterFirst = first.addingTimeInterval(TimeInterval(hours * 3600))
        var result = times.filter { $0 >= gapAfterFirst }
        if calendar.isDate(first, inSameDayAs: dayStart) { result.insert(first, at: 0) }

        // the hospital dose counts toward the most a day
        if let max = medicine.maxPerDay, calendar.isDate(given, inSameDayAs: dayStart) {
            result = Array(result.prefix(Swift.max(0, max - 1)))
        }
        return result
    }

    // twice a day at set times with no every N hours rule, the only kind whose hospital dose fills a slot
    static func isTwiceDaily(_ medicine: some MedicineFacts) -> Bool {
        medicine.action == .take && medicine.timesOfDay.count == 2 && medicine.minHoursBetween == nil
    }

    // a hospital dose this many minutes or less before the first paper time may be that dose, the patient says
    // half the 12 hour gap of a twice a day medicine
    static let earlyDoseMinutes = 6 * 60

    // the first paper time a readable hospital time came early for, nil when it is not early or too early to tell
    static func earlyDoseSlot(given: Date, minutes: [Int]) -> Date? {
        guard let first = minutes.min() else { return nil }
        let slot = DayMath.calendar.startOfDay(for: given).addingTimeInterval(TimeInterval(first * 60))
        let early = slot.timeIntervalSince(given) / 60
        return early > 0 && early <= Double(earlyDoseMinutes) ? slot : nil
    }

    // the paper time that day the hospital already gave: the last one at or before the paper's
    // last given time, else the one the patient said counts, nil when neither
    static func hospitalDose(for medicine: some MedicineFacts, onDay day: Int, from surgeryDate: Date) -> Date? {
        guard isTwiceDaily(medicine) else { return nil }
        let times = medicine.timesOfDay.sorted().map { DayMath.date(forDay: day, minute: $0, from: surgeryDate) }
        let calendar = DayMath.calendar
        if let given = medicine.lastGivenAt, let slot = times.last(where: { $0 <= given && calendar.isDate($0, inSameDayAs: given) }) {
            return slot
        }
        guard let said = medicine.hospitalDoseAt else { return nil }
        return times.first { calendar.isDate($0, inSameDayAs: said) && DayMath.minuteOfDay($0) == DayMath.minuteOfDay(said) }
    }

    // saved patietn log
    static func savedLog<Medicine: MedicineFacts>(for medicine: Medicine, at time: Date) -> Medicine.Log? {
        medicine.doseLogs.first { abs($0.scheduledFor.timeIntervalSince(time)) < 60 }
    }

    
    // due missed taken or upcoming
    static func state<Log: DoseLogFacts>(at time: Date, log: Log?, now: Date) -> DoseSlotState {
        if let log {
            return log.status == .taken ? .taken : .skipped
        }
        let minutesLate = Int(now.timeIntervalSince(time) / 60)
        if minutesLate > missedMinutesAfter { return .missed }
        if minutesLate >= -dueMinutesBefore { return .due }
        return .upcoming
    }

  // for only when needed
    static func asNeededStatus(for medicine: some MedicineFacts, now: Date) -> AsNeededStatus {
        let todayStart = DayMath.calendar.startOfDay(for: now)

        // log
        let taken = medicine.doseLogs
            .filter { $0.status == .taken }
            .sorted { $0.loggedAt > $1.loggedAt }
        var todayCount = taken.filter { $0.loggedAt >= todayStart }.count
        var last = taken.first?.loggedAt

        // the hospital dose from the paper counts like a logged one
        if let given = medicine.lastGivenAt {
            if DayMath.calendar.isDate(given, inSameDayAs: now) { todayCount += 1 }
            if last.map({ given > $0 }) ?? true { last = given }
        }

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

    // for daily goals, how many of the logged times fall today up to now
    static func goalCount(loggedAt: [Date], now: Date) -> Int {
        let todayStart = DayMath.calendar.startOfDay(for: now)
        return loggedAt.filter { $0 >= todayStart && $0 <= now }.count
    }
}
