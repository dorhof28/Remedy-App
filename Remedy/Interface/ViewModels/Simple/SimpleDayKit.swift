//
//  SimpleDayKit.swift
//  Remedy
//
//  simple look helpers: stepping to any day inside my day, and the pain over the last days
//

import Foundation

// the day stepper words and rules for my day
struct SimpleDayKit {

    let surgeryDate: Date?
    let today: Int
    // first and last plan day the stepper offers
    let range: ClosedRange<Int>

    init(plan: CarePlan?, now: Date) {
        let model = PlanViewModel(plan: plan, now: now)
        surgeryDate = plan?.surgeryDate
        today = model.todayID
        if let plan, plan.surgeryDate != nil {
            let found = Journey.range(for: plan, today: model.todayID)
            range = found.lowerBound...found.upperBound
        } else {
            range = model.todayID...model.todayID
        }
    }

    static let earlierTitle = "Earlier day"
    static let pickTitle = "Pick a day"
    static let journeyTitle = "My whole journey"
    static let pickerDone = "Done"

    // the stepper only shows with a surgery date to count days from
    var canStep: Bool { surgeryDate != nil }

    // one day earlier or later, never past the ends
    func step(_ day: Int, by amount: Int) -> Int {
        min(max(day + amount, range.lowerBound), range.upperBound)
    }

    func canStep(_ day: Int, by amount: Int) -> Bool { step(day, by: amount) != day }

    // the real dates the picker allows
    var dateRange: ClosedRange<Date>? {
        guard let surgeryDate else { return nil }
        return DayMath.date(forDay: range.lowerBound, from: surgeryDate)...DayMath.date(forDay: range.upperBound, from: surgeryDate)
    }

    func date(forDay day: Int) -> Date {
        DayMath.date(forDay: day, from: surgeryDate ?? .now)
    }

    func day(for date: Date) -> Int {
        guard let surgeryDate else { return today }
        return min(max(DayMath.dayOffset(of: date, from: surgeryDate), range.lowerBound), range.upperBound)
    }
}

// pain from the saved check-ins, one dot per day
struct SimpleCheckInTrend {

    // one saved pain score
    struct Entry: Equatable {
        let day: Int
        let pain: Int
        var savedAt: Date = .distantPast
    }

    // one point on the pain chart
    struct Point: Identifiable, Equatable {
        let day: Int
        let pain: Int
        let label: String
        var id: Int { day }
    }

    static let title = "Pain over the last days"
    static let note = "0 is no pain, 10 is the worst"
    static let shownDays = 7

    let points: [Point]

    init(entries: [Entry], surgeryDate: Date?) {
        // the newest answer of each day, the last few days in order
        var latest: [Int: Entry] = [:]
        for entry in entries where entry.savedAt >= (latest[entry.day]?.savedAt ?? .distantPast) {
            latest[entry.day] = entry
        }
        let recent = latest.values.sorted { $0.day < $1.day }.suffix(Self.shownDays)
        points = recent.map { entry in
            let label = surgeryDate.map { DayMath.date(forDay: entry.day, from: $0).formatted(.dateTime.weekday(.abbreviated)) } ?? "Day \(entry.day)"
            return Point(day: entry.day, pain: min(max(entry.pain, 0), 10), label: label)
        }
    }

    init(checkIns: [CheckIn], surgeryDate: Date?) {
        self.init(entries: checkIns.map { Entry(day: $0.day, pain: $0.pain, savedAt: $0.createdAt) }, surgeryDate: surgeryDate)
    }

    // a line needs at least two days
    var isShown: Bool { points.count >= 2 }

    var spoken: String {
        Self.title + ". " + points.map { "\($0.label) \($0.pain)" }.joined(separator: ", ")
    }
}

// words for the row that opens how papers are read, before the first scan
enum SimpleReaderRowWords {
    static let title = "How Remedy reads your papers"
    static let hint = "Pick or download a model before you scan"

    // the second line is what is picked now
    static func current(_ settings: ModelSettings) -> String {
        settings.plannerChoice.displayName
    }
}
