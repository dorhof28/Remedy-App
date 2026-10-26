//
//  RemedyWidget.swift
//  RemedyWidget
//
//  today and journey widgets for the home screen and lock screen
//

import SwiftUI
import WidgetKit

// brand colours the widget cant reach the apps theme file
private enum WidgetColors {
    static let brand = Color(red: 0.08, green: 0.50, blue: 0.41)       // #158069

    static func tone(_ name: String) -> Color {
        switch name {
        case "stop": return .red
        case "caution": return .orange
        case "neutral": return .gray
        default: return brand
        }
    }
}

// MARK: - Today widget

// one widget moment
struct RemedyEntry: TimelineEntry {
    let date: Date
    let data: WidgetEntryData
}

// gives the widget its lines
struct RemedyProvider: TimelineProvider {

    // shown in the widget gallery and while loading
    private let sample = WidgetEntryData(date: .now, eyebrow: "Due now \u{00B7} 2:00 PM",
                                         title: "Acetaminophen", detail: "2 tablets", symbol: "bell.fill",
                                         dayText: "Day 3 of recovery",
                                         upNext: [WidgetLine(time: "6:00 PM", title: "Cephalexin 500 mg", symbol: "pills.fill"),
                                                  WidgetLine(time: "8:00 PM", title: "Acetaminophen", symbol: "pills.fill")],
                                         takenText: "2 of 5 taken", takenFraction: 0.4)

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
        // ask again after midnight so a new day shows even if the app isnt opened
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: list.isEmpty ? [RemedyEntry(date: .now, data: empty)] : list,
                            policy: .after(tomorrow)))
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

// how the today widget looks in each size
struct RemedyWidgetView: View {
    let entry: RemedyEntry
    @Environment(\.widgetFamily) private var family

    private var data: WidgetEntryData { entry.data }

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
            .tint(WidgetColors.brand)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label(data.title, systemImage: data.symbol)
        case .accessoryCircular:
            if let fraction = data.takenFraction {
                Gauge(value: fraction) {
                    Image(systemName: "pills.fill")
                } currentValueLabel: {
                    Text("\(Int((fraction * 100).rounded()))%")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: data.symbol).font(.title3)
                }
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                now
                upNext
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 12) {
                now
                if let text = data.takenText, let fraction = data.takenFraction {
                    ProgressView(value: fraction) { Text(text).font(.caption.weight(.semibold)) }
                }
                Divider()
                upNext
                Spacer(minLength: 0)
            }
        default:
            now
        }
    }

    // the thing to do right now
    private var now: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(data.eyebrow, systemImage: data.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .lineLimit(1)
            Text(data.title)
                .font(family == .accessoryRectangular ? .headline : .title3.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !data.detail.isEmpty {
                Text(data.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if family != .accessoryRectangular {
                Spacer(minLength: 0)
                if let day = data.dayText, !day.isEmpty {
                    Text(day)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // the next few things
    private var upNext: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Up next")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let lines = data.upNext, !lines.isEmpty {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 6) {
                        Image(systemName: line.symbol)
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(line.time).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            Text(line.title).font(.caption).lineLimit(1)
                        }
                    }
                }
            } else {
                Text("Nothing else today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RemedyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RemedyToday", provider: RemedyProvider()) { entry in
            RemedyWidgetView(entry: entry)
        }
        .configurationDisplayName("Remedy today")
        .description("What to take or stop now and what comes next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Journey widget

// one day of the journey widget
struct JourneyEntry: TimelineEntry {
    let date: Date
    let journey: WidgetJourney?
}

// a new entry every midnight so the countdown moves without the app
struct JourneyProvider: TimelineProvider {

    private var sample: WidgetJourney {
        let calendar = Calendar.current
        let surgery = calendar.date(byAdding: .day, value: 4, to: calendar.startOfDay(for: .now)) ?? .now
        func stop(_ day: Int, _ title: String, _ symbol: String, _ tone: String) -> WidgetStop {
            let date = calendar.date(byAdding: .day, value: day, to: surgery) ?? surgery
            return WidgetStop(date: date, month: date.formatted(.dateTime.month(.abbreviated)).uppercased(),
                              dayNumber: date.formatted(.dateTime.day()), weekday: date.formatted(.dateTime.weekday(.abbreviated)),
                              label: "", title: title, symbol: symbol, tone: tone, isSurgery: day == 0)
        }
        return WidgetJourney(surgeryDate: surgery, procedure: "Knee replacement", stops: [
            stop(-2, "Stop ibuprofen", "nosign", "stop"),
            stop(-1, "Shower with Hibiclens", "checklist", "caution"),
            stop(0, "Surgery", "star.circle.fill", "info"),
            stop(14, "Check-up with your surgeon", "stethoscope", "info"),
        ])
    }

    func placeholder(in context: Context) -> JourneyEntry {
        JourneyEntry(date: .now, journey: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (JourneyEntry) -> Void) {
        completion(JourneyEntry(date: .now, journey: WidgetSnapshot.loadJourney() ?? sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JourneyEntry>) -> Void) {
        let journey = WidgetSnapshot.loadJourney()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [JourneyEntry(date: .now, journey: journey)]
        for day in 1...7 {
            if let date = calendar.date(byAdding: .day, value: day, to: today) {
                entries.append(JourneyEntry(date: date, journey: journey))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// countdown and the next key days
struct JourneyWidgetView: View {
    let entry: JourneyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
            .tint(WidgetColors.brand)
    }

    @ViewBuilder
    private var content: some View {
        if let journey = entry.journey {
            let stops = upcoming(journey)
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text(countdownLine(journey)).font(.headline)
                    if let next = stops.first { Label(next.title, systemImage: next.symbol).font(.caption) }
                }
            case .systemMedium:
                HStack(alignment: .top, spacing: 12) {
                    countdown(journey)
                        .frame(width: 84, alignment: .leading)
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(stops.prefix(3), id: \.self) { stop in
                            column(stop)
                        }
                    }
                }
            case .systemLarge:
                VStack(alignment: .leading, spacing: 10) {
                    countdown(journey)
                    Divider()
                    ForEach(Array(stops.prefix(6).enumerated()), id: \.element) { index, stop in
                        row(stop, isLast: index == min(stops.count, 6) - 1)
                    }
                    Spacer(minLength: 0)
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    countdown(journey)
                    Spacer(minLength: 0)
                    if let next = stops.first {
                        Label(next.title, systemImage: next.symbol)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(WidgetColors.tone(next.tone))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Label("Open Remedy to set up your plan", systemImage: "map")
                .font(.subheadline)
        }
    }

    // MARK: - Pieces

    // big number like 4 days to surgery
    private func countdown(_ journey: WidgetJourney) -> some View {
        let days = daysToSurgery(journey)
        return VStack(alignment: .leading, spacing: 0) {
            Text(days > 0 ? "\(days)" : days == 0 ? "Today" : "Day \(-days)")
                .font(.system(size: days == 0 || days < 0 ? 26 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(days > 0 ? (days == 1 ? "day to surgery" : "days to surgery") : days == 0 ? "Surgery day" : "of recovery")
                .font(.caption.weight(.semibold))
            if !journey.procedure.isEmpty, family != .systemSmall {
                Text(journey.procedure)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // icon date and title stacked for the medium size
    private func column(_ stop: WidgetStop) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            icon(stop)
            Text("\(stop.weekday) \(stop.dayNumber)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(stop.title)
                .font(.caption)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // date tile rail icon and title for the large size
    private func row(_ stop: WidgetStop, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                Text(stop.month).font(.system(size: 9, weight: .bold)).foregroundStyle(.tint)
                Text(stop.dayNumber).font(.headline).monospacedDigit()
            }
            .frame(width: 34)
            icon(stop)
            Text(stop.title)
                .font(.subheadline.weight(stop.isSurgery ? .bold : .regular))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func icon(_ stop: WidgetStop) -> some View {
        Image(systemName: stop.symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(WidgetColors.tone(stop.tone)))
    }

    // MARK: - Dates

    private func daysToSurgery(_ journey: WidgetJourney) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date),
                                       to: calendar.startOfDay(for: journey.surgeryDate)).day ?? 0
    }

    private func countdownLine(_ journey: WidgetJourney) -> String {
        let days = daysToSurgery(journey)
        if days > 1 { return "Surgery in \(days) days" }
        if days == 1 { return "Surgery tomorrow" }
        if days == 0 { return "Surgery today" }
        return "Day \(-days) of recovery"
    }

    // key days from this entrys day on
    private func upcoming(_ journey: WidgetJourney) -> [WidgetStop] {
        let start = Calendar.current.startOfDay(for: entry.date)
        return journey.stops.filter { $0.date >= start && $0.title != "Nothing new today" }
    }
}

struct JourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RemedyJourney", provider: JourneyProvider()) { entry in
            JourneyWidgetView(entry: entry)
        }
        .configurationDisplayName("Remedy journey")
        .description("Countdown to surgery and the key days coming up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

// widget entry point
@main
struct RemedyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RemedyWidget()
        JourneyWidget()
    }
}
