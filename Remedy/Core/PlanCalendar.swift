//
//  PlanCalendar.swift
//  Remedy
//
//  the plan days laid out as calendar weeks for the swipe strip
//

import Foundation

// seven days in a row starting on the calendar's first weekday
nonisolated struct CalendarWeek: Identifiable, Equatable {
    // plan day of the first day
    let id: Int
    var days: [Int] { (id..<(id + 7)).map { $0 } }
}

