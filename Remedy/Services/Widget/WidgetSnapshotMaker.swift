import SwiftData
//
//  WidgetSnapshotMaker.swift
//  Remedy
//
//  builds and saves what the widgets show
//

import Foundation
import WidgetKit

// builds the widget snapshot from the plan and saves it only when it changed
enum WidgetSnapshotMaker {

    // what the widget last got
    nonisolated(unsafe) private static var lastSignature = ""

    // most lines in up next
    static let maxUpNext = 3

    // lines for now and every later dose today plus the journey
    static func save(plan: CarePlan?, now: Date) {
        guard let plan else {
            guard lastSignature != "none" else { return }
            lastSignature = "none"
            WidgetSnapshot.save([])
            WidgetSnapshot.saveJourney(nil)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        // now plus every dose time still to come today
        let today = TodayViewModel(plan: plan, now: now)
        var times: Set<Date> = [now]
        if today.layout == .afterSurgery {
            let later = DoseSchedule.slotsWithCheck(onDay: today.day, plan: plan, now: now)
                .map(\.scheduledFor)
                .filter { $0 > now }
            times.formUnion(later)
        }

        let entries = times.sorted().map { time in
            entry(for: TodayViewModel(plan: plan, now: time), plan: plan, at: time)
        }
        let stops = journey(plan: plan, today: today.day)
        // skip the write and the timeline reload when nothing the widget shows changed
        let signature = entries.enumerated().map { index, e in
            "\(index == 0 ? 0 : e.date.timeIntervalSince1970)|\(e.eyebrow)|\(e.title)|\(e.detail)|\(e.dayText ?? "")|\(e.upNext ?? [])|\(e.takenText ?? "")|\(e.nextEvent as Any)"
        }.joined(separator: "\n") + "\n\(stops as Any)"
        guard signature != lastSignature else { return }
        lastSignature = signature
        WidgetSnapshot.save(entries)
        WidgetSnapshot.saveJourney(stops)
        WidgetCenter.shared.reloadAllTimelines()
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
            let slots = DoseSchedule.slotsWithCheck(onDay: today.day, plan: plan, now: time)
            // the same count as today's list: doses, to-dos and the check-in
            let progress = today.dayProgress(checkIn: checkIn(onDay: today.day, plan: plan))
            if progress.total > 0 {
                data.takenText = "\(progress.done) of \(progress.total) done"
                data.takenFraction = Double(progress.done) / Double(progress.total)
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
        data.nextEvent = nextEvent(plan: plan, after: time)
        return data
    }

    // the saved check-in for a plan day, if there is one
    private static func checkIn(onDay day: Int, plan: CarePlan) -> CheckIn? {
        let descriptor = FetchDescriptor<CheckIn>(predicate: #Predicate { $0.day == day })
        return (try? plan.modelContext?.fetch(descriptor))?.first
    }

    // the next appointment from the plan with its day and time
    static func nextEvent(plan: CarePlan, after time: Date) -> WidgetLine? {
        guard let visit = plan.appointments.filter({ $0.date > time }).min(by: { $0.date < $1.date }) else { return nil }
        let day = DayMath.calendar.isDate(visit.date, inSameDayAs: time) ? "Today" : DayMath.shortDate(visit.date)
        return WidgetLine(time: "\(day) \(DayMath.timeText(of: visit.date))", title: visit.title, symbol: "calendar")
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
