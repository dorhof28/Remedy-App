//
//  AskByReminder.swift
//  Remedy
//
//  the morning reminder to call the office about papers that disagree
//

import Foundation

// a reminder to call the office before the day a red card's papers start to disagree
nonisolated struct AskByReminder: Equatable {
    // Finding.key, so a reminder can be replaced or cancelled
    let findingKey: String
    let fireDate: Date
    let title: String
    let body: String
    // true once the ask-by day has passed, fires every day at 9 AM from fireDate until the plan is refreshed without it
    var repeatsDaily = false

    // 9:00 AM on the ask-by day
    static let morningMinute = 9 * 60

    // one per open red finding: on its ask-by day if still ahead, the next 9 AM when it says ask now,
    // and every day at 9 AM from the day after once its ask-by day has passed
    static func reminders(for findings: [Finding], surgeryDate: Date, contactName: String?, now: Date) -> [AskByReminder] {
        let name = contactName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let office = name.isEmpty ? "your care team" : "\(name)\u{2019}s office"
        return findings.compactMap { finding in
            guard finding.color == .red, !finding.isResolved else { return nil }
            // no nagging once every day the papers disagree about is past
            if finding.isOver(today: DayMath.dayOffset(of: now, from: surgeryDate)) { return nil }
            var fireDate = finding.askByDay.map { DayMath.date(forDay: $0, minute: morningMinute, from: surgeryDate) } ?? nextMorning(after: now)
            var repeats = false
            if let askBy = finding.askByDay, fireDate <= now {
                // passed and still open so nag daily starting the day after the ask-by day
                fireDate = max(nextMorning(after: now), DayMath.date(forDay: askBy + 1, minute: morningMinute, from: surgeryDate))
                repeats = true
            }
            guard fireDate > now else { return nil }
            return AskByReminder(findingKey: finding.key, fireDate: fireDate,
                                 title: "Your papers disagree about \(finding.medicine)",
                                 body: "Call \(office) about \(finding.medicine) today.", repeatsDaily: repeats)
        }
    }

    // 9:00 AM today if still ahead, else tomorrow
    private static func nextMorning(after now: Date) -> Date {
        let calendar = DayMath.calendar
        let today = calendar.date(bySettingHour: morningMinute / 60, minute: morningMinute % 60, second: 0, of: now) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
