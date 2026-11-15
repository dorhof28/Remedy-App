//
//  TonightHeadsUp.swift
//  Remedy
//
//  today shows only today, except in the evening when tomorrow needs getting ready for
//  surgery and its fasting are already in the day before's list, so this covers
//  a medicine that stops tomorrow and a visit early tomorrow
//

import Foundation

// the evening card about tomorrow: a stop that starts or an early visit
nonisolated enum TonightHeadsUp {

    // the evening starts at 5 PM
    static let eveningStart = 17 * 60
    // a visit before noon needs the night before
    static let earlyEnd = 12 * 60
    // the arrival and hospital question shows only when surgery is this close
    static let fillInDays = 3

    enum Kind: Equatable { case stop, visit }

    // one heads up row
    struct Item: Equatable, Identifiable {
        let kind: Kind
        let title: String
        let detail: String
        var id: String { "\(kind)-\(title)" }
    }

    // tomorrow's visit and its start minute
    struct Visit: Equatable {
        let title: String
        let minute: Int
    }

    static func isEvening(_ minuteOfDay: Int) -> Bool { minuteOfDay >= eveningStart }

    static func isEarly(_ minuteOfDay: Int) -> Bool { minuteOfDay < earlyEnd }

    // days until surgery, 0 on the day, the question waits until it is near
    static func asksForPlace(daysToSurgery: Int) -> Bool { daysToSurgery >= 0 && daysToSurgery <= fillInDays }

    // nothing before the evening, then only what changes tonight or early tomorrow
    static func items(minuteOfDay: Int, stopsTomorrow: [String], visitsTomorrow: [Visit]) -> [Item] {
        guard isEvening(minuteOfDay) else { return [] }
        var items: [Item] = []
        if !stopsTomorrow.isEmpty {
            items.append(Item(kind: .stop, title: "Stop \(PlainText.list(stopsTomorrow)) tomorrow",
                              detail: "Today is the last day to take \(stopsTomorrow.count > 1 ? "them" : "it")"))
        }
        for visit in visitsTomorrow.sorted(by: { $0.minute < $1.minute }) where isEarly(visit.minute) {
            items.append(Item(kind: .visit, title: visit.title, detail: "Tomorrow, \(DayMath.timeText(visit.minute))"))
        }
        return items
    }
}
