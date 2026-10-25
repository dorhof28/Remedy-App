//
//  WidgetSnapshotMaker.swift
//  Remedy
//
//  builds and saves the widget lines
//

import Foundation
import WidgetKit

enum WidgetSnapshotMaker {

    // lines for now and every later dose today
    static func save(plan: CarePlan?, now: Date) {
        defer { WidgetCenter.shared.reloadAllTimelines() }
        guard let plan else {
            WidgetSnapshot.save([])
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
            entry(for: TodayViewModel(plan: plan, now: time), at: time)
        }
        WidgetSnapshot.save(entries)
    }

    // the Today screen's top card squeezed into a widget
    private static func entry(for today: TodayViewModel, at time: Date) -> WidgetEntryData {
        switch today.layout {
        case .afterSurgery:
            let card = today.nowCard
            let detail = card.lines.count == 1 ? (card.lines.first?.how ?? "") : PlainText.list(card.lines.map(\.name))
            return WidgetEntryData(date: time, eyebrow: card.eyebrow, title: card.title,
                                   detail: detail, symbol: card.symbol)
        case .beforeSurgery, .surgeryDay:
            let card = today.beforeTopCard
            return WidgetEntryData(date: time, eyebrow: today.headerTitle, title: card.title,
                                   detail: PlainText.list(card.names), symbol: card.symbol)
        case .noPlan, .needsSurgeryDate:
            return WidgetEntryData(date: time, eyebrow: "Remedy", title: "Open Remedy to finish your plan",
                                   detail: "", symbol: "doc.text.viewfinder")
        }
    }
}
