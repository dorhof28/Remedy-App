//
//  ReminderPlan.swift
//  Remedy
//
//  which notifications to send worked out from the plan
//

import Foundation

// dose stop visit or task
enum ReminderKind: String {
    case dose
    case stop
    case visit
    case task
    case checkIn
}

// one notification to schedule, persistence names the saved kind ReminderItem
struct ReminderItemOf<LineID: Hashable>: Identifiable {
    let id: String                          // stable, so refreshing replaces instead of doubling
    let kind: ReminderKind
    let date: Date
    let title: String
    let body: String
    var medicineIDs: [LineID] = []          // dose reminders: what "I took it" logs
}

// works out every notification from the plan: doses, stops, visits, to-dos and the check-in
enum ReminderPlan {

    // "Time for Aspirin 81 mg" names every medicine due then
    static func doseTitle(_ medicines: [some MedicineFacts]) -> String {
        "Time for \(PlainText.list(medicines.map { MedicineText.fullName($0) }))"
    }

    // one medicine says how and why, more than one says how much of each
    static func doseBody(_ medicines: [some MedicineFacts]) -> String {
        if medicines.count == 1, let medicine = medicines.first {
            let take = medicine.amount.isEmpty ? "" : "Take \(medicine.amount)."
            let why = medicine.reason.isEmpty ? "" : PlainText.upperFirst(medicine.reason) + (medicine.reason.hasSuffix(".") ? "" : ".")
            return [take, why].filter { !$0.isEmpty }.joined(separator: " ")
        }
        let parts = medicines.map { $0.amount.isEmpty ? MedicineText.fullName($0) : "\($0.amount) of \(MedicineText.fullName($0))" }
        return "Take " + PlainText.list(parts) + "."
    }

    static let maxCount = 60        // under iPhone's limit of 64
    static let doseDaysAhead = 3
    static let otherDaysAhead = 14

    static let stopMinute = 8 * 60          // 8 AM
    static let taskMinute = 9 * 60          // 9 AM
    static let visitEveningMinute = 18 * 60 // 6 PM the day before
    static let visitHoursBefore = 2

    // every notification for the plan
    static func items<Plan: PlanFacts>(for plan: Plan, now: Date,
                                       skipped: SkippedLinesOf<Plan.Medicine.LineID>,
                                       checkInMinute: Int? = nil,
                                       checkedInDays: Set<Int> = []) -> [ReminderItemOf<Plan.Medicine.LineID>] {
        guard let surgeryDate = plan.surgeryDate,
              let today = DoseSchedule.today(for: plan, now: now) else { return [] }
        var items: [ReminderItemOf<Plan.Medicine.LineID>] = []

        // 1 doses one notification per time naming every medicine due then
        for day in today...(today + doseDaysAhead) {
            let open = DoseSchedule.slots(onDay: day, plan: plan, now: now, skipped: skipped).filter { $0.log == nil && !$0.givenInHospital }
            let byTime = Dictionary(grouping: open) { $0.scheduledFor }
            for (time, slots) in byTime {
                let medicines = slots.map(\.medicine)
                items.append(ReminderItemOf(id: "dose-\(Int(time.timeIntervalSince1970))", kind: .dose, date: time,
                                          title: doseTitle(medicines),
                                          body: doseBody(medicines),
                                          medicineIDs: slots.map { $0.medicine.lineID }))
            }
        }

        // 2 stop days, replaced lines get no stop reminder on a replaced day either
        for day in today...(today + otherDaysAhead) {
            let stops = plan.medicines.filter {
                $0.isConfirmed && $0.action == .stop && $0.startDay == day && !skipped.contains($0.lineID, onDay: day)
            }
            guard !stops.isEmpty else { continue }
            let names = stops.map { MedicineText.everydayName($0) }
            items.append(ReminderItemOf(id: "stop-\(day)", kind: .stop,
                                      date: DayMath.date(forDay: day, minute: stopMinute, from: surgeryDate),
                                      title: "Stop today: \(PlainText.list(names))",
                                      body: "Your papers say to stop \(DayMath.surgeryWords(forDay: day)). Put them away so you don\u{2019}t take one by mistake."))
        }

        // 3 visits the evening before and 2 hours before
        for visit in plan.appointments {
            let time = DayMath.timeText(of: visit.date)
            let place = visit.place.isEmpty ? "" : " at \(visit.place)"
            let visitDay = DayMath.dayOffset(of: visit.date, from: surgeryDate)
            let key = Int(visit.date.timeIntervalSince1970)
            items.append(ReminderItemOf(id: "visit-eve-\(key)", kind: .visit,
                                      date: DayMath.date(forDay: visitDay - 1, minute: visitEveningMinute, from: surgeryDate),
                                      title: "Tomorrow: \(visit.title)",
                                      body: "\(time)\(place).\(visit.bring.isEmpty ? "" : " Bring: \(PlainText.list(visit.bring)).")"))
            items.append(ReminderItemOf(id: "visit-soon-\(key)", kind: .visit,
                                      date: visit.date.addingTimeInterval(TimeInterval(-visitHoursBefore * 3600)),
                                      title: "\(visit.title) at \(time)", body: "In \(visitHoursBefore) hours\(place)."))
        }

        // 4 to-dos on their due day
        for task in plan.tasks where !task.isDone {
            guard let due = task.dueDay, due >= today, due <= today + otherDaysAhead else { continue }
            items.append(ReminderItemOf(id: "task-\(task.lineID.hashValue)", kind: .task,
                                      date: DayMath.date(forDay: due, minute: taskMinute, from: surgeryDate),
                                      title: "To do today", body: task.title))
        }

        // 5 the daily check-in at the patient's time, not on days already checked in
        if let minute = checkInMinute {
            for day in CheckInTime.reminderDays(today: today, checkedIn: checkedInDays) {
                items.append(ReminderItemOf(id: "checkin-\(day)", kind: .checkIn,
                                          date: CheckInTime.date(minute: minute, onDayOf: DayMath.date(forDay: day, from: surgeryDate)),
                                          title: "Time for your check-in",
                                          body: "It takes about a minute. Check in when you can."))
            }
        }

        // only the future soonest first under the limit
        let horizon = DayMath.date(forDay: today + otherDaysAhead + 1, from: surgeryDate)
        return items
            .filter { $0.date > now && $0.date < horizon }
            .sorted { $0.date < $1.date }
            .prefix(maxCount)
            .map { $0 }
    }
}
