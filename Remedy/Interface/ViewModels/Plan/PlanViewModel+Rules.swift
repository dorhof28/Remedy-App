//
//  PlanViewModel+Rules.swift
//  Remedy
//
//  paper instructions split into short lines with a do, avoid or fine mark, grouped by topic for both looks
//

import Foundation
import SwiftData

// plain words for each kind, never called rules on screen
extension RuleReminders.Kind {
    // the mark's word "Avoid" "Do" "Fine"
    var label: String { title }

    // do is the accent, avoid is caution, fine is plain grey
    var tone: Tone {
        switch self {
        case .dont: return .caution
        case .must: return .good
        case .may: return .neutral
        }
    }

    // the shape differs too: filled check do, outlined cross avoid, outlined check fine
    var markSymbol: String {
        switch self {
        case .dont: return "xmark.circle"
        case .must: return "checkmark.circle.fill"
        case .may: return "checkmark.circle"
        }
    }
}

// one short instruction line from a paper
struct ReminderRow: Identifiable {
    let id: String
    let text: String            // "No showers"
    let kind: RuleReminders.Kind
    let detail: String          // "Until Thu, Nov 12"
    let quote: String           // the paper's words
    var topic: InstructionTopic = .other
    var source: String = ""     // "From: your surgeon or the hospital, printed Nov 19 2026"

    var tone: Tone { kind.tone }
    var symbol: String { kind.markSymbol }
    var badge: String { kind.label }
    var spokenLabel: String { [kind.label, text, detail].filter { !$0.isEmpty }.joined(separator: ". ") }
}

// lines of one kind
struct ReminderGroup: Identifiable {
    let kind: RuleReminders.Kind
    let rows: [ReminderRow]

    var id: String { kind.rawValue }
    var title: String { kind.label }
    var tone: Tone { kind.tone }
    var symbol: String { kind.markSymbol }
    var countText: String { "\(rows.count)" }
}

// lines about one topic like bathing, avoid first
struct ReminderTopicGroup: Identifiable {
    let topic: InstructionTopic
    let rows: [ReminderRow]

    var id: String { topic.rawValue }
    var title: String { topic.title }
    var symbol: String { topic.symbol }
    // the plain outline symbol for the topic's icon tile
    var tileSymbol: String { topic.tileSymbol }
    var tone: Tone { rows.first?.tone ?? .neutral }

    // "1 avoid · 2 do", read out with the topic
    var summary: String {
        RuleReminders.Kind.allCases.compactMap { kind in
            let count = rows.filter { $0.kind == kind }.count
            return count == 0 ? nil : "\(count) \(kind.label.lowercased())"
        }
        .joined(separator: " \u{00B7} ")
    }
    var spokenLabel: String { "\(title). \(summary)" }
}

extension InstructionTopic {
    // topic icons from the design reference, plain outlines
    var tileSymbol: String {
        switch self {
        case .food: return "fork.knife"
        case .bathing: return "shower"
        case .activity: return "figure.walk"
        case .driving: return "car"
        case .wound: return "bandage"
        case .medicines: return "pills"
        case .bring: return "bag"
        case .other: return "ellipsis.circle"
        }
    }
}

// which instructions the Instructions screen shows
enum InstructionsFilter: String, CaseIterable, Identifiable {
    case now, later, all
    var id: String { rawValue }
}

extension RuleRow {
    // the instruction as short lines, one when it is already short
    var reminders: [RuleReminders.Reminder] {
        let text = rule.title.isEmpty ? rule.quote : rule.title
        let split = RuleReminders.split(text, isAllowed: rule.isAllowed)
        return split.isEmpty ? [RuleReminders.Reminder(text: text, kind: rule.isAllowed ? .may : .dont)] : split
    }

    // short lines under a long instruction
    var reminderRows: [ReminderRow] { reminderRows(detail: Self.reminderDetail(detail: detail, headline: headline)) }

    // a rule split into short reminders, each with its paper line
    func reminderRows(detail lineDetail: String) -> [ReminderRow] {
        let base = "\(rule.persistentModelID.hashValue)"
        let source = PaperSourceLine.text(paperID: rule.paperID, in: rule.plan) ?? ""
        return reminders.enumerated().map { index, reminder in
            ReminderRow(id: "\(base)-\(index)", text: reminder.text, kind: reminder.kind,
                        detail: lineDetail, quote: rule.quote,
                        topic: ReminderRow.topic(text: reminder.text, quote: rule.quote), source: source)
        }
    }

    // the mark already says fine, so a bare "OK now" is left off but real limits stay
    static func reminderDetail(detail: String, headline: String) -> String {
        let text = detail.isEmpty ? headline : detail
        return text == "OK now" || text == "OK" ? "" : text
    }
}

extension ReminderRow {
    // the line's own words decide, the paper quote helps when they say nothing
    static func topic(text: String, quote: String) -> InstructionTopic {
        let own = InstructionTopic.of(text)
        return own == .other && !quote.isEmpty ? InstructionTopic.of(quote) : own
    }
}

extension PlanViewModel {
    // in effect now as short lines, avoid first, then do, then fine
    var nowReminderGroups: [ReminderGroup] { reminderGroups(onDay: day) }

    // the same for any picked day on the calendar
    func reminderGroups(onDay picked: Int) -> [ReminderGroup] {
        let rows = reminderRows(onDay: picked)
        return RuleReminders.Kind.allCases.compactMap { kind in
            let matching = rows.filter { $0.kind == kind }
            return matching.isEmpty ? nil : ReminderGroup(kind: kind, rows: matching)
        }
    }

    // the same lines by topic, topics in a fixed order, other last, avoid first inside each
    func topicGroups(onDay picked: Int) -> [ReminderTopicGroup] {
        Self.topicGroups(reminderRows(onDay: picked))
    }

    // reminders grouped by topic, don'ts first
    static func topicGroups(_ rows: [ReminderRow]) -> [ReminderTopicGroup] {
        let kinds = RuleReminders.Kind.allCases
        return InstructionTopic.allCases.compactMap { topic in
            let matching = rows.filter { $0.topic == topic }
            guard !matching.isEmpty else { return nil }
            let sorted = kinds.flatMap { kind in matching.filter { $0.kind == kind } }
            return ReminderTopicGroup(topic: topic, rows: sorted)
        }
    }

    // MARK: - Instructions screen

    static let instructionsTitle = "Instructions"
    var instructionsTitle: String { Self.instructionsTitle }
    var instructionsEmptyText: String { "Your papers don\u{2019}t list any instructions for this time." }

    // lines that start later, with when they start and end
    var laterReminderRows: [ReminderRow] {
        var seen = Set<String>()
        return comingUpRows.flatMap { row in
            row.reminderRows(detail: laterDetail(row.rule))
        }
        .filter { seen.insert("\($0.kind.rawValue)|\($0.text.lowercased())").inserted }
    }

    // "Starting Nov 20 · until Dec 3"
    private func laterDetail(_ rule: CareRule) -> String {
        guard let surgeryDate = plan?.surgeryDate else { return "" }
        let start = "Starting \(DayMath.shortDate(forDay: DoseSchedule.startDay(of: rule), from: surgeryDate))"
        guard let end = rule.endDay else { return start }
        return "\(start) \u{00B7} until \(DayMath.shortDate(forDay: end, from: surgeryDate))"
    }

    func instructionRows(_ filter: InstructionsFilter) -> [ReminderRow] {
        switch filter {
        case .now: return reminderRows(onDay: day)
        case .later: return laterReminderRows
        case .all: return reminderRows(onDay: day) + laterReminderRows
        }
    }

    func instructionGroups(_ filter: InstructionsFilter) -> [ReminderTopicGroup] {
        Self.topicGroups(instructionRows(filter))
    }

    // read to me: every line of the shown topics
    func instructionsSpoken(_ filter: InstructionsFilter) -> String {
        let groups = instructionGroups(filter)
        guard !groups.isEmpty else { return instructionsEmptyText }
        return groups.map { group in
            ([group.title] + group.rows.map(\.spokenLabel)).joined(separator: ". ")
        }
        .joined(separator: ". ")
    }

    // the simple look uses the same name
    var simpleDosTitle: String { Self.instructionsTitle }
    var simpleDosIntro: String { "What your papers say for now" }

    // every line in effect on a day, the same words from two papers show once
    func reminderRows(onDay picked: Int) -> [ReminderRow] {
        var seen = Set<String>()
        return activeRuleRows(onDay: picked).flatMap(\.reminderRows)
            .filter { seen.insert("\($0.kind.rawValue)|\($0.text.lowercased())").inserted }
    }
}
