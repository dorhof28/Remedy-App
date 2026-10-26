//
//  JourneyStops.swift
//  Remedy
//
//  the key days of the whole journey for the overview and the widget
//

import Foundation

// where a key day sits compared to today
enum JourneyStopState {
    case done
    case today
    case next
    case later
}

// one key day
struct JourneyStop: Identifiable {
    let day: Int
    let date: Date
    let month: String           // NOV
    let dayNumber: String       // 3
    let weekday: String         // Mon
    let label: String           // 3 days before surgery
    let titles: [String]        // what happens that day most important first
    let kind: DayEventKind?     // nil on a quiet today
    let state: JourneyStopState

    var id: Int { day }
}

extension Journey {

    // most titles shown for one day
    static let maxTitles = 3

    // every day something happens plus today and surgery day
    static func stops(plan: CarePlan, today: Int) -> [JourneyStop] {
        guard let surgeryDate = plan.surgeryDate else { return [] }
        var days = Set(range(for: plan, today: today).filter { !events(onDay: $0, plan: plan).isEmpty })
        days.insert(today)
        days.insert(0)
        let sorted = days.sorted()
        let next = sorted.first { $0 > today }

        return sorted.map { day in
            let events = self.events(onDay: day, plan: plan)
            var titles = events.prefix(maxTitles).map(\.title)
            if events.count > maxTitles { titles.append("and \(events.count - maxTitles) more") }
            if titles.isEmpty { titles = ["Nothing new today"] }

            let state: JourneyStopState
            if day < today { state = .done } else if day == today { state = .today } else if day == next { state = .next } else { state = .later }

            let date = DayMath.date(forDay: day, from: surgeryDate)
            return JourneyStop(day: day, date: date, month: monthFormatter.string(from: date).uppercased(),
                               dayNumber: DayMath.dayNumber(forDay: day, from: surgeryDate),
                               weekday: DayMath.weekdayLetters(forDay: day, from: surgeryDate),
                               label: DayMath.surgeryWords(forDay: day), titles: titles,
                               kind: events.first?.kind, state: state)
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}

// the icon for each kind of day
extension DayEventKind {
    var symbol: String {
        switch self {
        case .surgery: return "star.circle.fill"
        case .stopMedicine: return "nosign"
        case .visit: return "stethoscope"
        case .task: return "checklist"
        case .ruleChange: return "figure.walk"
        case .startMedicine: return "pills.fill"
        case .endMedicine: return "checkmark.seal"
        }
    }

    // a plain name the widget turns into a colour
    var toneName: String {
        switch self {
        case .stopMedicine: return "stop"
        case .task: return "caution"
        case .visit, .surgery, .startMedicine: return "info"
        case .ruleChange, .endMedicine: return "neutral"
        }
    }
}
