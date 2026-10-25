//
//  Journey.swift
//  Remedy
//
//  one place to access what happens each day
//

import Foundation
import SwiftData

// kinds of things that happen on a day
enum DayEventKind: Equatable {
    case surgery
    case stopMedicine
    case visit
    case task
    case ruleChange
    case startMedicine
    case endMedicine
}

// one thing on one day
struct DayEvent: Identifiable {
    let id: String
    let kind: DayEventKind
    let title: String
    let detail: String
    var medicine: MedicineInstruction?
    var appointment: Appointment?
}

// one day in the picker
struct JourneyDay: Identifiable {
    let id: Int
    let isPast: Bool
    let isToday: Bool
    let isSurgery: Bool
    let markerKind: DayEventKind?
    let weekday: String
    let dayNumber: String
    let spokenLabel: String
}

enum Journey {

    // whcih days to show
    static func range(for plan: CarePlan, today: Int) -> ClosedRange<Int> {
        let medicines = plan.medicines.filter { $0.isConfirmed }
        var days: [Int] = [-7, 14, today]
        days += medicines.compactMap { $0.startDay }
        days += medicines.compactMap { $0.endDay }
        days += plan.tasks.compactMap { $0.dueDay }
        if let surgeryDate = plan.surgeryDate {
            days += plan.appointments.map { DayMath.dayOffset(of: $0.date, from: surgeryDate) }
        }
     
        // reasnoable ln
        let low = max(days.min() ?? -7, -30)
        let high = min(days.max() ?? 14, 60)
        return low...high
    }

// days for picker
    static func days(in range: ClosedRange<Int>, plan: CarePlan, today: Int) -> [JourneyDay] {
        guard let surgeryDate = plan.surgeryDate else { return [] }
        return range.map { day in
            let events = self.events(onDay: day, plan: plan)
            var spoken = "\(DayMath.longDate(forDay: day, from: surgeryDate)), \(DayMath.surgeryWords(forDay: day))"
            if day == today { spoken += ", today" }
            if !events.isEmpty { spoken += ", \(PlainText.count(events.count, "thing"))" }

            return JourneyDay(
                id: day,
                isPast: day < today,
                isToday: day == today,
                isSurgery: day == 0,
                markerKind: events.first?.kind,     // events come most important first
                weekday: DayMath.weekdayLetters(forDay: day, from: surgeryDate),
                dayNumber: DayMath.dayNumber(forDay: day, from: surgeryDate),
                spokenLabel: spoken
            )
        }
    }

    // events / day
    static func events(onDay day: Int, plan: CarePlan) -> [DayEvent] {
        let medicines = plan.medicines.filter { $0.isConfirmed }
        var result: [DayEvent] = []

        // surgery itself
        if day == 0 {
            let title = plan.procedure.isEmpty ? "Surgery" : "Surgery: \(plan.procedure)"
            result.append(DayEvent(id: "surgery", kind: .surgery, title: title,
                                   detail: "Follow your before-surgery papers until you leave for the hospital."))
        }

        // medicines to stop from this day
        for medicine in medicines where medicine.action == .stop && medicine.startDay == day {
            result.append(DayEvent(id: "stop-\(medicine.persistentModelID)", kind: .stopMedicine,
                                   title: "Stop \(MedicineText.everydayName(medicine))",
                                   detail: medicine.reason.isEmpty ? "Until your surgeon says it\u{2019}s OK" : medicine.reason,
                                   medicine: medicine))
        }

        // visits on this day
        if let surgeryDate = plan.surgeryDate {
            let visits = plan.appointments
                .filter { DayMath.dayOffset(of: $0.date, from: surgeryDate) == day }
                .sorted { $0.date < $1.date }
            for visit in visits {
                let place = visit.place.isEmpty ? "" : " · \(visit.place)"
                result.append(DayEvent(id: "visit-\(visit.persistentModelID)", kind: .visit, title: visit.title,
                                       detail: DayMath.timeText(of: visit.date) + place, appointment: visit))
            }
        }

        // todo on this day
        for task in plan.tasks where task.dueDay == day {
            result.append(DayEvent(id: "task-\(task.persistentModelID)", kind: .task, title: task.title,
                                   detail: task.isDone ? "Done" : "To do"))
        }

        // rules that start or end on this day
        for rule in plan.rules {
            if rule.startDay == day {
                let title = rule.isAllowed ? "\(rule.title): OK from today" : "\(rule.title) starts"
                result.append(DayEvent(id: "rule-start-\(rule.persistentModelID)", kind: .ruleChange,
                                       title: title, detail: rule.condition))
            }
            if rule.endDay == day {
                result.append(DayEvent(id: "rule-end-\(rule.persistentModelID)", kind: .ruleChange,
                                       title: "Last day: \(PlainText.lowerFirst(rule.title))", detail: rule.condition))
            }
        }

        // medicines that start on this day
        for medicine in medicines where (medicine.action == .take || medicine.action == .takeAsNeeded) && medicine.startDay == day {
            let how = medicine.action == .take ? "Every day" : "Only when needed"
            result.append(DayEvent(id: "start-\(medicine.persistentModelID)", kind: .startMedicine,
                                   title: "Start \(MedicineText.fullName(medicine))", detail: how, medicine: medicine))
        }

        // last days
        for medicine in medicines where medicine.action != .stop && medicine.endDay == day {
            let title = medicine.action == .okToTake
                ? "Last day \(MedicineText.everydayName(medicine)) is OK"
                : "Last day of \(MedicineText.fullName(medicine))"
            result.append(DayEvent(id: "end-\(medicine.persistentModelID)", kind: .endMedicine,
                                   title: title, detail: "", medicine: medicine))
        }

        return result
    }
}
