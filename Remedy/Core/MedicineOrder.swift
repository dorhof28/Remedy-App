//
//  MedicineOrder.swift
//  Remedy
//
//  which medicines list a medicine belongs to today and in what order
//

import Foundation

// the groups of the medicines tab in the order they show
nonisolated enum MedicineGroup: String, CaseIterable {
    case takeToday = "take-today"
    case dontTake = "stopped"
    case stopSoon = "soon"
    case okToTake = "ok"
    case done = "done"
}

// what the order needs to know about one medicine
nonisolated struct MedicineOrderItem: Equatable {
    // caller's own index so the result maps back
    let id: Int
    let action: MedicineAction
    let startDay: Int?
    let endDay: Int?
    // when the next dose is due, nil = nothing left today or no time
    let nextDue: Date?
    let name: String
}

// which group a medicine is in today and the order inside each group
nonisolated enum MedicineOrder {

    // the group a medicine is in today
    static func group(action: MedicineAction, startDay: Int?, endDay: Int?, today: Int) -> MedicineGroup {
        if let endDay, endDay < today { return .done }
        let started = (startDay ?? Int.min) <= today
        switch action {
        case .take, .takeAsNeeded: return started ? .takeToday : .okToTake
        case .stop: return started ? .dontTake : .stopSoon
        case .okToTake: return .okToTake
        }
    }

    // every group even when empty, rows in each sorted
    static func groups(_ items: [MedicineOrderItem], today: Int) -> [(group: MedicineGroup, items: [MedicineOrderItem])] {
        let byGroup = Dictionary(grouping: items) { group(action: $0.action, startDay: $0.startDay, endDay: $0.endDay, today: today) }
        return MedicineGroup.allCases.map { group in
            (group, (byGroup[group] ?? []).sorted { isBefore($0, $1, in: group, today: today) })
        }
    }

    // mandatory first then as needed, soonest due, then the day it changes, then the name
    private static func isBefore(_ a: MedicineOrderItem, _ b: MedicineOrderItem, in group: MedicineGroup, today: Int) -> Bool {
        switch group {
        case .takeToday:
            let rankA = a.action == .take ? 0 : 1
            let rankB = b.action == .take ? 0 : 1
            if rankA != rankB { return rankA < rankB }
            if a.nextDue != b.nextDue { return (a.nextDue ?? .distantFuture) < (b.nextDue ?? .distantFuture) }
        case .dontTake:
            // stopping today first
            let todayA = a.startDay == today
            let todayB = b.startDay == today
            if todayA != todayB { return todayA }
        case .stopSoon:
            if a.startDay != b.startDay { return (a.startDay ?? Int.max) < (b.startDay ?? Int.max) }
        case .okToTake:
            // OK now before the ones that start later, those by start day
            let laterA = (a.startDay ?? Int.min) > today
            let laterB = (b.startDay ?? Int.min) > today
            if laterA != laterB { return !laterA }
            if a.startDay != b.startDay { return (a.startDay ?? Int.min) < (b.startDay ?? Int.min) }
        case .done:
            // most recently finished first
            if a.endDay != b.endDay { return (a.endDay ?? Int.min) > (b.endDay ?? Int.min) }
        }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}
