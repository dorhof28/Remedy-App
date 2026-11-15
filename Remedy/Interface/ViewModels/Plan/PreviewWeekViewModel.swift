//
//  PreviewWeekViewModel.swift
//  Remedy
//
//  plays days 1 to 7 after surgery before surgery, never touches AppClock
//

import Foundation
import SwiftData

// one line in the preview
struct PreviewLine: Identifiable {
    let id: String
    let title: String
    let detail: String
}

// one day of the preview
struct PreviewDay {
    let day: Int
    let title: String               // "Day 1"
    let dateText: String            // "Fri Nov 13"
    let medicines: [PreviewLine]    // set-time medicines with times
    let asNeeded: [PreviewLine]     // only when needed
    let rules: [PreviewLine]        // can and can't
    let visits: [PreviewLine]
    let isEmpty: Bool
}

// a look at the first week after surgery, one day at a time
struct PreviewWeekViewModel {
    static let days = Array(1...7)

    let plan: CarePlan?
    private(set) var index = 0

    init(plan: CarePlan?) {
        self.plan = plan
    }

    // preview only works with a surgery date
    var isAvailable: Bool { plan?.surgeryDate != nil }

    var buttonTitle: String { "Preview my first week" }
    var title: String { "Your first week" }
    var intro: String { "This is only a preview. Nothing here is saved or changed." }
    var backTitle: String { "Back" }
    var nextTitle: String { isLast ? "Done" : "Next" }
    var closeTitle: String { "Close" }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == Self.days.count - 1 }
    var progressText: String { "Day \(index + 1) of \(Self.days.count)" }

    mutating func next() { if index < Self.days.count - 1 { index += 1 } }
    mutating func select(_ position: Int) { index = min(max(position, 0), Self.days.count - 1) }
    mutating func back() { if index > 0 { index -= 1 } }

    var current: PreviewDay { day(Self.days[index]) }

    // what a day after surgery will hold
    func day(_ day: Int) -> PreviewDay {
        guard let plan, let surgeryDate = plan.surgeryDate else {
            return PreviewDay(day: day, title: "Day \(day)", dateText: "", medicines: [], asNeeded: [],
                              rules: [], visits: [], isEmpty: true)
        }
        let skipped = PaperCheckReport.of(plan).skipped

        // medicines that day, replaced lines left out
        let active = plan.medicines.filter {
            $0.action == .take && $0.isConfirmed && !$0.isGroup
                && !skipped.contains($0.persistentModelID, onDay: day) && DoseSchedule.isActive($0, on: day)
        }
        let timed = active.filter { !$0.timesOfDay.isEmpty }
            .sorted { ($0.timesOfDay.min() ?? 0) < ($1.timesOfDay.min() ?? 0) }
            .map { medicine in
                PreviewLine(id: "m\(medicine.persistentModelID.hashValue)",
                            title: Self.name(medicine),
                            detail: Self.timesText(medicine))
            }
        let asNeeded = active.filter { $0.timesOfDay.isEmpty }.map { medicine in
            PreviewLine(id: "n\(medicine.persistentModelID.hashValue)",
                        title: Self.name(medicine),
                        detail: medicine.onlyIf.isEmpty ? "Only when needed" : medicine.onlyIf)
        }

        let rules = plan.rules.filter { DoseSchedule.isActive($0, on: day) }.map { rule in
            PreviewLine(id: "r\(rule.persistentModelID.hashValue)",
                        title: rule.title,
                        detail: (rule.isAllowed ? "Allowed" : "Not yet") + (rule.condition.isEmpty ? "" : " \u{00B7} \(rule.condition)"))
        }

        let visits = plan.appointments
            .filter { DayMath.dayOffset(of: $0.date, from: surgeryDate) == day }
            .sorted { $0.date < $1.date }
            .map { visit in
                PreviewLine(id: "v\(visit.persistentModelID.hashValue)",
                            title: visit.title,
                            detail: [DayMath.timeText(of: visit.date), visit.doctor, visit.place]
                                .filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
            }

        return PreviewDay(day: day,
                          title: "Day \(day)",
                          dateText: DayMath.shortDate(forDay: day, from: surgeryDate),
                          medicines: timed, asNeeded: asNeeded, rules: rules, visits: visits,
                          isEmpty: timed.isEmpty && asNeeded.isEmpty && rules.isEmpty && visits.isEmpty)
    }

    // "Acetaminophen 500 mg"
    private static func name(_ medicine: MedicineInstruction) -> String {
        // skip the strength when the name already has it
        if medicine.name.localizedCaseInsensitiveContains(medicine.strength) { return medicine.name }
        return [medicine.name, medicine.strength].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // "8:00 AM, 2:00 PM · 2 tablets"
    private static func timesText(_ medicine: MedicineInstruction) -> String {
        let times = medicine.timesOfDay.sorted().map { DayMath.shortTimeText($0) }.joined(separator: ", ")
        return [times, medicine.amount, medicine.foodNote].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    var emptyText: String { "Nothing planned for this day." }
    var footer: String { "A preview. Nothing here needs doing yet." }

    // MARK: - Day strip and the Back and Next capsules

    // one day in the strip: "Sat" over "21"
    struct StripDay: Identifiable {
        let id: Int             // place in the week
        let weekday: String
        let number: String
        let hasSomething: Bool
        let spokenLabel: String
    }

    var strip: [StripDay] {
        guard let surgeryDate = plan?.surgeryDate else { return [] }
        return Self.days.enumerated().map { position, day in
            let date = DayMath.date(forDay: day, from: surgeryDate)
            return StripDay(id: position,
                            weekday: Self.shortWeekday.string(from: date),
                            number: DayMath.dayNumber(forDay: day, from: surgeryDate),
                            hasSomething: !self.day(day).isEmpty,
                            spokenLabel: "\(TodayViewModel.weekdayDate(date)), \(Self.afterWords(day))")
        }
    }

    // "Saturday · 2 days after surgery"
    var dayHeader: String {
        let day = Self.days[index]
        guard let surgeryDate = plan?.surgeryDate else { return Self.afterWords(day) }
        return "\(TodayViewModel.weekday(DayMath.date(forDay: day, from: surgeryDate))) \u{00B7} \(Self.afterWords(day))"
    }

    // "Friday" on the Back capsule, empty on the first day
    var backLabel: String { isFirst ? "" : weekdayName(at: index - 1) }
    // "Sunday" on the Next capsule, "Done" on the last day
    var nextLabel: String { isLast ? "Done" : weekdayName(at: index + 1) }

    private func weekdayName(at position: Int) -> String {
        guard let surgeryDate = plan?.surgeryDate, Self.days.indices.contains(position) else { return "" }
        return TodayViewModel.weekday(DayMath.date(forDay: Self.days[position], from: surgeryDate))
    }

    static func afterWords(_ day: Int) -> String { day == 1 ? "1 day after surgery" : "\(day) days after surgery" }

    private static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()
    var medicinesTitle: String { "Medicines" }
    var asNeededTitle: String { "Only if you need them" }
    var rulesTitle: String { "Can and can\u{2019}t" }
    var visitsTitle: String { "Visits" }

    // read aloud
    func spokenLabel(for day: PreviewDay) -> String {
        let lines = (day.medicines + day.asNeeded + day.rules + day.visits).map { "\($0.title). \($0.detail)" }
        return ([day.title, day.dateText] + (lines.isEmpty ? [emptyText] : lines)).joined(separator: ". ")
    }
}
