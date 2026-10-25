//
//  ReminderPlan.swift
//  Remedy
//
//  which notifications to send worked out from the plan
//

import Foundation
import SwiftData

// dose stop visit or task
enum ReminderKind: String {
    case dose
    case stop
    case visit
    case task
}

// one notification to schedule
struct ReminderItem: Identifiable {
    let id: String                          // stable, so refreshing replaces instead of doubling
    let kind: ReminderKind
    let date: Date
    let title: String
    let body: String
    var medicineIDs: [PersistentIdentifier] = []   // dose reminders: what "I took it" logs
}

enum ReminderPlan {

    static let maxCount = 60        // under iPhone's limit of 64
    static let doseDaysAhead = 3
    static let otherDaysAhead = 14

    static let stopMinute = 8 * 60          // 8 AM
    static let taskMinute = 9 * 60          // 9 AM
    static let visitEveningMinute = 18 * 60 // 6 PM the day before
    static let visitHoursBefore = 2

    // every notification for the plan
    static func items(for plan: CarePlan, now: Date) -> [ReminderItem] {
        guard let surgeryDate = plan.surgeryDate,
              let today = DoseSchedule.today(for: plan, now: now) else { return [] }
        var items: [ReminderItem] = []

        // 1 doses one notification per time naming every medicine due then
        for day in today...(today + doseDaysAhead) {
            let open = DoseSchedule.slots(onDay: day, plan: plan, now: now).filter { $0.log == nil }
            let byTime = Dictionary(grouping: open) { $0.scheduledFor }
            for (time, slots) in byTime {
                let names = slots.map { slot in
                    let how = slot.medicine.amount.isEmpty ? "" : " (\(slot.medicine.amount))"
                    return MedicineText.fullName(slot.medicine) + how
                }
                items.append(ReminderItem(id: "dose-\(Int(time.timeIntervalSince1970))", kind: .dose, date: time,
                                          title: "Time for your medicine",
                                          body: PlainText.list(names),
                                          medicineIDs: slots.map { $0.medicine.persistentModelID }))
            }
        }

        let medicines = plan.medicines.filter { $0.isConfirmed }

        // 2 stop days
        for day in today...(today + otherDaysAhead) {
            let stops = medicines.filter { $0.action == .stop && $0.startDay == day }
            guard !stops.isEmpty else { continue }
            let names = stops.map { MedicineText.everydayName($0) }
            items.append(ReminderItem(id: "stop-\(day)", kind: .stop,
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
            items.append(ReminderItem(id: "visit-eve-\(key)", kind: .visit,
                                      date: DayMath.date(forDay: visitDay - 1, minute: visitEveningMinute, from: surgeryDate),
                                      title: "Tomorrow: \(visit.title)",
                                      body: "\(time)\(place).\(visit.bring.isEmpty ? "" : " Bring: \(PlainText.list(visit.bring)).")"))
            items.append(ReminderItem(id: "visit-soon-\(key)", kind: .visit,
                                      date: visit.date.addingTimeInterval(TimeInterval(-visitHoursBefore * 3600)),
                                      title: "\(visit.title) at \(time)", body: "In \(visitHoursBefore) hours\(place)."))
        }

        // 4 to-dos on their due day
        for task in plan.tasks where !task.isDone {
            guard let due = task.dueDay, due >= today, due <= today + otherDaysAhead else { continue }
            items.append(ReminderItem(id: "task-\(task.persistentModelID.hashValue)", kind: .task,
                                      date: DayMath.date(forDay: due, minute: taskMinute, from: surgeryDate),
                                      title: "To do today", body: task.title))
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
