//
//  RemedyWidget.swift
//  RemedyWidget
//
//  today and journey widgets for the home screen and lock screen
//

import ActivityKit
import SwiftUI
import WidgetKit

// brand colours the widget cant reach the apps theme file
private enum WidgetColors {
    static let brand = Color(red: 0.08, green: 0.50, blue: 0.41)       // #158069
    static let mint = Color(red: 0.48, green: 0.84, blue: 0.75)        // #7BD6C0
    static let pink = Color(red: 0.99, green: 0.76, blue: 0.84)        // #FCC3D5

    // the snapshot stores tone names, the widget turns them into colors
    static func tone(_ name: String) -> Color {
        switch name {
        case "stop": return .red
        case "caution": return .orange
        case "neutral": return .gray
        default: return brand
        }
    }

    // colour of the top label by what is due
    static func tone(_ kind: WidgetKind) -> Color {
        switch kind {
        case .missed: return .orange
        default: return brand
        }
    }
}

// soft mint and pink wash behind home screen widgets
private struct WidgetWash: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strength = scheme == .dark ? 0.22 : 0.40
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [WidgetColors.mint.opacity(strength), WidgetColors.pink.opacity(strength * 0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
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

    // the entry in effect now then every later one today
    // lines saved on an earlier day are old so they are left out
    private func entries() -> [RemedyEntry] {
        let calendar = Calendar.current
        let now = Date.now
        let saved = WidgetSnapshot.load().filter { calendar.isDate($0.date, inSameDayAs: now) }
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
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.redactionReasons) private var redaction

    private var data: WidgetEntryData { entry.data }
    private var isAccessory: Bool {
        family == .accessoryInline || family == .accessoryCircular || family == .accessoryRectangular
    }

    var body: some View {
        content
            .tint(WidgetColors.brand)
            .containerBackground(for: .widget) {
                if isAccessory || renderingMode != .fullColor {
                    Color.clear
                } else {
                    WidgetWash()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            // a locked phone only gets a general line
            if redaction.contains(.privacy) {
                Label("Next up in Remedy", systemImage: "pills.fill")
            } else {
                Label(data.inlineText, systemImage: data.symbol)
            }
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
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(data.eyebrow, systemImage: data.symbol)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(data.title)
                    .font(.headline)
                    .lineLimit(1)
                    .privacySensitive()
                if let text = data.takenText, let fraction = data.takenFraction {
                    ProgressView(value: fraction) { Text(text).font(.caption2) }
                        .progressViewStyle(.linear)
                } else if !data.detail.isEmpty {
                    Text(data.detail).font(.caption).lineLimit(1).privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                now
                upNext
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) { Divider() }
            }
        case .systemLarge, .systemExtraLarge:
            VStack(alignment: .leading, spacing: 14) {
                now
                upNext
                Spacer(minLength: 0)
            }
        default:
            now
        }
    }

    // the thing to do right now with how far through the doses today
    private var now: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(data.eyebrow, systemImage: data.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetColors.tone(data.kind))
                .lineLimit(1)
            Text(data.title)
                .font(.system(family == .systemSmall ? .headline : .title3, design: .rounded, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .privacySensitive()
            if !data.detail.isEmpty {
                Text(data.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemSmall ? 2 : 3)
                    .privacySensitive()
            }
            Spacer(minLength: 0)
            progress
            if let day = data.dayText, !day.isEmpty, family != .systemSmall {
                Text(day)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // how many doses are taken today
    @ViewBuilder
    private var progress: some View {
        if let text = data.takenText, let fraction = data.takenFraction {
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(WidgetColors.brand)
                Text(text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } else if family == .systemSmall, let day = data.dayText, !day.isEmpty {
            Text(day)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // the next few things
    private var upNext: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up next")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let lines = data.upNext, !lines.isEmpty {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 8) {
                        Image(systemName: line.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WidgetColors.brand)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(WidgetColors.mint.opacity(0.35)))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(line.time).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            Text(line.title).font(.caption.weight(.medium)).lineLimit(1).privacySensitive()
                        }
                    }
                }
            } else {
                Text("Nothing else today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if family == .systemLarge || family == .systemExtraLarge, let event = data.nextEvent {
                Label("\(event.time) \(event.title)", systemImage: event.symbol)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
}

// the today widget: next dose or event from the app's snapshot
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
        // one stop on the journey line, dated from surgery
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

    // a stop's small round icon
    private func icon(_ stop: WidgetStop) -> some View {
        Image(systemName: stop.symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(WidgetColors.tone(stop.tone)))
    }

    // MARK: - Dates

    // whole days from today to surgery
    private func daysToSurgery(_ journey: WidgetJourney) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date),
                                       to: calendar.startOfDay(for: journey.surgeryDate)).day ?? 0
    }

    // surgery in 3 days, surgery tomorrow, or the day after surgery
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

// the journey widget: where today sits between before and after surgery
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
        RemedyLiveActivity()
    }
}

// MARK: - Live Activity for busy days

// apple maps link for the hospital
private func directionsURL(_ address: String?) -> URL? {
    guard let address, !address.isEmpty,
          let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
    return URL(string: "https://maps.apple.com/?daddr=\(encoded)")
}

// the big line: what comes next and a timer when there is a time
private struct ActivityHeadline: View {
    let state: RemedyActivityAttributes.ContentState
    var isStale = false
    var timerFont: Font = .title2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.headline)
                .font(.headline)
                .lineLimit(2)
            if let target = state.countdownTo, target > .now, !isStale {
                Text(timerInterval: Date.now...target, countsDown: true)
                    .font(timerFont.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetColors.brand)
            }
        }
    }
}

// the steps still to do, next one first
private struct ActivitySteps: View {
    let state: RemedyActivityAttributes.ContentState
    var limit = 3

    var body: some View {
        let todo = state.steps.filter { !$0.isDone }
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(todo.prefix(limit).enumerated()), id: \.offset) { index, step in
                Label(step.title, systemImage: index == 0 ? "circle.inset.filled" : "circle")
                    .font(.caption)
                    .foregroundStyle(index == 0 ? .primary : .secondary)
                    .lineLimit(1)
            }
            if todo.count > limit {
                Text("+\(todo.count - limit) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// done so far
private struct ActivityProgress: View {
    let state: RemedyActivityAttributes.ContentState
    var showsLabel = true

    var body: some View {
        let done = state.doneCount ?? state.steps.filter(\.isDone).count
        let total = state.totalCount ?? state.steps.count
        if total > 0 {
            ProgressView(value: Double(done), total: Double(total)) {
                if showsLabel { Text("\(done) of \(total) done").font(.caption2.weight(.semibold)) }
            }
            .accessibilityValue("\(done) of \(total) done")
            .progressViewStyle(.linear)
            .tint(WidgetColors.brand)
        }
    }
}

// opens maps for the hospital address
private struct DirectionsButton: View {
    let address: String?

    var body: some View {
        if let url = directionsURL(address) {
            Link(destination: url) {
                Label("Directions", systemImage: "map.fill")
                    .font(.caption.bold())
            }
        }
    }
}

// short text for the compact island: timer or done count
private struct CompactTrailing: View {
    let state: RemedyActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if let target = state.countdownTo, target > .now, !isStale {
            Text(timerInterval: Date.now...target, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 56)
                .foregroundStyle(WidgetColors.brand)
        } else if let done = state.doneCount, let total = state.totalCount {
            Text("\(done)/\(total)").monospacedDigit().foregroundStyle(WidgetColors.brand)
        } else {
            Image(systemName: "checklist")
        }
    }
}

// the busy day live activity on the lock screen and dynamic island
struct RemedyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RemedyActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                // day and place on one line, like the app's screen 29
                HStack(alignment: .firstTextBaseline) {
                    Label(context.attributes.dayTitle, systemImage: "cross.case.fill")
                        .font(.headline)
                    Spacer(minLength: 8)
                    if let place = context.attributes.placeName, !place.isEmpty {
                        Text(place)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if context.state.showsHeadlineOnly == true {
                    Text(context.state.headline)
                        .font(.title.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    if let detail = context.state.detail {
                        Text(detail)
                            .font(.body)
                            .lineLimit(3)
                            .privacySensitive()
                    }
                    ActivityProgress(state: context.state, showsLabel: false)
                } else {
                    ActivityHeadline(state: context.state, isStale: context.isStale, timerFont: .largeTitle)
                        .privacySensitive()
                    ActivityProgress(state: context.state)
                    ActivitySteps(state: context.state, limit: 3)
                        .privacySensitive()
                    DirectionsButton(address: context.attributes.directionsAddress)
                }
            }
            .padding()
            .activityBackgroundTint(WidgetColors.mint.opacity(0.25))
            .activitySystemActionForegroundColor(WidgetColors.brand)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "cross.case.fill").foregroundStyle(WidgetColors.brand)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.dayTitle)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    ActivityHeadline(state: context.state, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ActivityProgress(state: context.state)
                        ActivitySteps(state: context.state, limit: 2)
                        DirectionsButton(address: context.attributes.directionsAddress)
                    }
                }
            } compactLeading: {
                Image(systemName: "cross.case.fill").foregroundStyle(WidgetColors.brand)
            } compactTrailing: {
                CompactTrailing(state: context.state, isStale: context.isStale)
            } minimal: {
                Image(systemName: "cross.case.fill").foregroundStyle(WidgetColors.brand)
            }
            .keylineTint(WidgetColors.brand)
        }
    }
}
