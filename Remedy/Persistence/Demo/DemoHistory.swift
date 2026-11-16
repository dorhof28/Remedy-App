//
//  DemoHistory.swift
//  Remedy
//
//  DEMO ONLY fills the days already lived on a fake plan so it looks used
//  doses taken a few minutes late, one skipped, one missed today, pain pills, check-ins, goals and done to-dos
//  only runs on sample data, never on a real plan
//

import Foundation
import SwiftData

// the past days of a demo plan, as if the patient had been using the app since coming home
enum DemoHistory {

    // minutes late each dose was taken, picked in turn so the log looks real
    private static let lateBy = [2, 6, 1, 9, 4, 0, 12, 3, 7, 5]

    // pain pills as needed by day after surgery, as hour and minute
    private static let painPills: [Int: [(Int, Int)]] = [
        1: [(14, 5), (18, 30), (23, 0)],
        2: [(7, 15), (12, 0), (17, 40), (22, 45)],
        3: [(8, 0), (14, 30), (21, 10)],
        4: [(8, 10)],
    ]

    // how the patient felt each evening, pain 0 to 10 and a short note
    private static let checkIns: [Int: (Int, String)] = [
        1: (7, "First night home. Hard to sleep."),
        2: (6, "Walked to the kitchen and back 3 times."),
        3: (5, "Less swelling with ice. PT exercises are getting easier."),
        4: (5, "Feeling better in the morning."),
    ]

    // fills doses, pain pills, check-ins, goals and to-dos from the day after surgery up to now
    // safe to run again: a dose that already has an answer is left alone
    static func fill(_ plan: CarePlan, now: Date, in context: ModelContext) {
        guard let surgery = plan.surgeryDate, let today = DoseSchedule.today(for: plan, now: now), today >= 1 else { return }
        // a long recovery only gets its last week
        let firstDay = max(1, today - 6)
        let skipped = PaperCheckReport.of(plan).skipped
        let alreadyLogged = plan.medicines.contains { !$0.doseLogs.isEmpty }

        // every scheduled dose an hour or more ago, except the ones left on purpose
        let open = { (day: Int) in
            DoseSchedule.slots(onDay: day, plan: plan, now: now, skipped: skipped)
                .filter { $0.log == nil && !$0.givenInHospital && $0.scheduledFor <= now.addingTimeInterval(-3600) }
        }
        // the one missed dose is today's latest past one, first by name, so it shows on Today
        let pastToday = open(today)
        let latest = pastToday.map(\.minute).max()
        let missed = alreadyLogged ? nil : pastToday.filter { $0.minute == latest }.min { $0.medicine.name < $1.medicine.name }
        // the one skipped dose is last night's stool softener, or the last evening dose
        let lastEvening = today - 1 >= firstDay ? open(today - 1).filter { $0.minute >= 18 * 60 } : []
        let skippedDose = alreadyLogged ? nil : lastEvening.first { $0.medicine.name.lowercased().hasPrefix("senn") } ?? lastEvening.last

        var turn = 0
        // a second run leaves today alone so the missed dose stays missed
        for day in stride(from: firstDay, through: alreadyLogged ? today - 1 : today, by: 1) {
            for slot in open(day) {
                turn += 1
                if slot.scheduledFor == missed?.scheduledFor && slot.medicine.persistentModelID == missed?.medicine.persistentModelID { continue }
                let isSkipped = slot.scheduledFor == skippedDose?.scheduledFor && slot.medicine.persistentModelID == skippedDose?.medicine.persistentModelID
                let late = TimeInterval(lateBy[turn % lateBy.count] * 60)
                let log = DoseLog(scheduledFor: slot.scheduledFor, status: isSkipped ? .skipped : .taken,
                                  loggedAt: slot.scheduledFor.addingTimeInterval(isSkipped ? 0 : late))
                context.insert(log)
                log.medicine = slot.medicine
            }
        }

        // pain pills taken as needed, only the first time so a second paper does not add more
        if !alreadyLogged, let pill = plan.medicines.first(where: { $0.action == .takeAsNeeded && $0.maxPerDay != nil }) {
            for day in firstDay...today {
                for (hour, minute) in painPills[min(day, 4)] ?? [] {
                    let time = DayMath.date(forDay: day, minute: hour * 60 + minute, from: surgery)
                    guard time < now.addingTimeInterval(-1800), day > 1 || time > DayMath.date(forDay: 1, minute: 13 * 60, from: surgery) else { continue }
                    let log = DoseLog(scheduledFor: time, status: .taken, loggedAt: time)
                    context.insert(log)
                    log.medicine = pill
                }
            }
        }

        // a check-in each past evening, today's is left for the demo
        let saved = Set(((try? context.fetch(FetchDescriptor<CheckIn>())) ?? []).map(\.day))
        let checkInMinute = plan.checkInMinute ?? 19 * 60
        for day in firstDay..<today where !saved.contains(day) {
            let (pain, note) = checkIns[min(day, 4)] ?? (4, "")
            let checkIn = CheckIn(day: day, pain: max(pain - max(0, day - 4), 2), note: note)
            checkIn.createdAt = DayMath.date(forDay: day, minute: checkInMinute + lateBy[day % lateBy.count], from: surgery)
            context.insert(checkIn)
        }

        // goals met on past days, today partly done
        if !alreadyLogged {
            for goal in plan.goals where goal.logs.isEmpty {
                for day in firstDay...today where DoseSchedule.isGoalActive(startDay: goal.startDay, endDay: goal.endDay, on: day) {
                    let count = day == today ? 1 : (day == 1 ? max(1, goal.target - 1) : goal.target)
                    for index in 0..<count {
                        let time = DayMath.date(forDay: day, minute: 9 * 60 + index * 210 + lateBy[index % lateBy.count], from: surgery)
                        guard time < now else { continue }
                        let log = GoalLog(loggedAt: time)
                        context.insert(log)
                        log.goal = goal
                    }
                }
            }
        }

        // to-dos due before today are done
        for task in plan.tasks where !task.isDone {
            guard let due = task.dueDay, due < today else { continue }
            task.isDone = true
            task.doneAt = DayMath.date(forDay: due, minute: 10 * 60, from: surgery)
        }
        context.saveNow()
    }
}
