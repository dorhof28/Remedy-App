//
//  WidgetSnapshotMaker.swift
//  Remedy
//
//  builds and saves what the widgets show
//

import Foundation
import WidgetKit

enum WidgetSnapshotMaker {

    // most lines in up next
    static let maxUpNext = 3

    // lines for now and every later dose today plus the journey
    static func save(plan: CarePlan?, now: Date) {
        defer { WidgetCenter.shared.reloadAllTimelines() }
        guard let plan else {
            WidgetSnapshot.save([])
            WidgetSnapshot.saveJourney(nil)
            return
        }

        // now plus every dose time still to come today
        let today = TodayViewModel(plan: plan, now: now)
        var times: Set<Date> = [now]
        if today.layout == .afterSurgery {
            let later = DoseSchedule.slots(onDay: today.day, plan: plan, now: now)
                .map(\.scheduledFor)
                .filter { $0 > now }
            times.formUnion(later)
        }

        let entries = times.sorted().map { time in
            entry(for: TodayViewModel(plan: plan, now: time), plan: plan, at: time)
        }
        WidgetSnapshot.save(entries)
        WidgetSnapshot.saveJourney(journey(plan: plan, today: today.day))
    }

    // the line for right now also used by the glass bar above the tabs
    static func current(plan: CarePlan, now: Date) -> WidgetEntryData {
        entry(for: TodayViewModel(plan: plan, now: now), plan: plan, at: now)
    }

    // the Today screen's top card squeezed into a widget
    private static func entry(for today: TodayViewModel, plan: CarePlan, at time: Date) -> WidgetEntryData {
        var data: WidgetEntryData
        switch today.layout {
        case .afterSurgery:
            let card = today.nowCard
            let detail = card.lines.count == 1 ? (card.lines.first?.how ?? "") : PlainText.list(card.lines.map(\.name))
            data = WidgetEntryData(date: time, eyebrow: card.eyebrow, title: card.title,
                                   detail: detail, symbol: card.symbol)
            let slots = DoseSchedule.slots(onDay: today.day, plan: plan, now: time)
            let taken = slots.filter { $0.state == .taken }.count
            if !slots.isEmpty {
                data.takenText = "\(taken) of \(slots.count) taken"
                data.takenFraction = Double(taken) / Double(slots.count)
            }
            data.upNext = slots.filter { $0.scheduledFor > time }.prefix(maxUpNext).map { slot in
                WidgetLine(time: DayMath.shortTimeText(slot.minute), title: MedicineText.fullName(slot.medicine), symbol: "pills.fill")
            }
        case .beforeSurgery, .surgeryDay:
            let card = today.beforeTopCard
            data = WidgetEntryData(date: time, eyebrow: today.headerTitle, title: card.title,
                                   detail: PlainText.list(card.names), symbol: card.symbol)
            data.upNext = Journey.stops(plan: plan, today: today.day)
                .filter { $0.day > today.day }
                .prefix(maxUpNext)
                .map { WidgetLine(time: "\($0.weekday) \($0.dayNumber)", title: $0.titles.first ?? "", symbol: $0.kind?.symbol ?? "calendar") }
        case .noPlan, .needsSurgeryDate:
            return WidgetEntryData(date: time, eyebrow: "Remedy", title: "Open Remedy to finish your plan",
                                   detail: "", symbol: "doc.text.viewfinder")
        }
        data.dayText = today.headerTitle
        return data
    }

    // every key day from today on plus the last done one for context
    private static func journey(plan: CarePlan, today: Int) -> WidgetJourney? {
        guard let surgeryDate = plan.surgeryDate else { return nil }
        let stops = Journey.stops(plan: plan, today: today).map { stop in
            WidgetStop(date: stop.date, month: stop.month, dayNumber: stop.dayNumber, weekday: stop.weekday,
                       label: stop.label, title: stop.titles.first ?? "", symbol: stop.kind?.symbol ?? "calendar",
                       tone: stop.kind?.toneName ?? "info", isSurgery: stop.day == 0)
        }
        return WidgetJourney(surgeryDate: surgeryDate, procedure: plan.procedure, stops: stops)
    }
}
