//
//  RemedyWidget.swift
//  RemedyWidget
//
//  home screen and lock screen widget
//

import SwiftUI
import WidgetKit

// one widget moment
struct RemedyEntry: TimelineEntry {
    let date: Date
    let data: WidgetEntryData
}

// gives the widget its lines
struct RemedyProvider: TimelineProvider {

    // shown in the widget gallery and while loading
    private let sample = WidgetEntryData(date: .now, eyebrow: "Due now \u{00B7} 2:00 PM",
                                         title: "Acetaminophen", detail: "2 tablets", symbol: "bell.fill")

    func placeholder(in context: Context) -> RemedyEntry {
        RemedyEntry(date: .now, data: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (RemedyEntry) -> Void) {
        completion(entries().first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemedyEntry>) -> Void) {
        let list = entries()
        let empty = WidgetEntryData(date: .now, eyebrow: "Remedy", title: "Open Remedy to set up your plan",
                                    detail: "", symbol: "doc.text.viewfinder")
        completion(Timeline(entries: list.isEmpty ? [RemedyEntry(date: .now, data: empty)] : list,
                            policy: .atEnd))
    }

    // the entry in effect now then every later one
    private func entries() -> [RemedyEntry] {
        let saved = WidgetSnapshot.load()
        let now = Date.now
        var result: [RemedyEntry] = []
        if let current = saved.last(where: { $0.date <= now }) {
            result.append(RemedyEntry(date: now, data: current))
        }
        result += saved.filter { $0.date > now }.map { RemedyEntry(date: $0.date, data: $0) }
        return result
    }
}

// how the widget looks
struct RemedyWidgetView: View {
    let entry: RemedyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(entry.data.eyebrow, systemImage: entry.data.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .lineLimit(1)
            Text(entry.data.title)
                .font(family == .accessoryRectangular ? .headline : .title3.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !entry.data.detail.isEmpty {
                Text(entry.data.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
        .tint(Color(red: 0.08, green: 0.50, blue: 0.41))      // brand mint
    }
}

struct RemedyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RemedyToday", provider: RemedyProvider()) { entry in
            RemedyWidgetView(entry: entry)
        }
        .configurationDisplayName("Remedy today")
        .description("What to take or stop, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// widget entry point
@main
struct RemedyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RemedyWidget()
    }
}
