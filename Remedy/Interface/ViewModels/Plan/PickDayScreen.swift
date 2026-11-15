//
//  PickDayScreen.swift
//  Remedy
//
//  words for pick a day (screen 41): the calendar's marks always come with words on the day itself
//

import Foundation

// the sheet for jumping to any plan day
struct PickDayScreen {
    let plan: CarePlan?
    let now: Date

    let title = "Pick a Day"
    let cancelButton = "Cancel"
    let todayButton = "Today"
    let surgeryWord = "Surgery"
    let visitWord = "Visit"
    let todayWord = "Today"
    let footer = "Tap a day to open it. The dots always come with words on the day itself."

    private var surgeryDate: Date? { plan?.surgeryDate }

    // the plan day for a picked date
    func day(of date: Date) -> Int? {
        guard let surgeryDate else { return nil }
        return DayMath.dayOffset(of: date, from: surgeryDate)
    }

    var surgeryDay: Date? { surgeryDate }
    var visitDays: [Date] { (plan?.appointments ?? []).map(\.date) }
}
