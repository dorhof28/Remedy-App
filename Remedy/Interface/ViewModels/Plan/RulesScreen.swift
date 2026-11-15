//
//  RulesScreen.swift
//  Remedy
//
//  words for the rules list (screen 43) and one rule (screen 44), sorted into now, later and done
//

import Foundation
import SwiftData

// rules under one title
struct RulesGroup: Identifiable {
    let id: String
    let title: String
    let lines: [PlanLine]
}

// every rule split into now, later and over
struct RulesScreen {

    let plan: CarePlan?
    let now: Date
    private let base: PlanViewModel

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        self.base = PlanViewModel(plan: plan, now: now)
    }

    let title = "Rules"
    let readAloudButton = "Read Aloud"
    let footer = "Tap a rule to see your paper\u{2019}s exact words."
    let emptyText = "Your papers don\u{2019}t list any rules."

    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    var groups: [RulesGroup] {
        let rules = plan?.rules ?? []
        let statuses = rules.map { (rule: $0, status: PlanWording.ruleStatus($0, today: base.day, surgeryDate: surgeryDate)) }
        func lines(_ kinds: [RuleStatusKind], tone: (CareRule) -> Tone) -> [PlanLine] {
            statuses.filter { kinds.contains($0.status.kind) }
                .sorted { ($0.rule.isAllowed ? 1 : 0, $0.rule.startDay ?? 0) < ($1.rule.isAllowed ? 1 : 0, $1.rule.startDay ?? 0) }
                .map { item in
                    PlanLine(id: "\(item.rule.persistentModelID.hashValue)", symbol: Self.symbol(item.rule),
                             tone: tone(item.rule), title: item.rule.title, subtitle: subtitle(item.rule, item.status),
                             target: .rule(item.rule.persistentModelID))
                }
        }
        let result = [
            RulesGroup(id: "now", title: "Now", lines: lines([.notAllowed, .allowed]) { $0.isAllowed ? .good : .stop }),
            RulesGroup(id: "later", title: "Later", lines: lines([.allowedLater, .notAllowedLater]) { _ in .info }),
            RulesGroup(id: "done", title: "Done", lines: lines([.ended]) { _ in .neutral })
        ]
        return result.filter { !$0.lines.isEmpty }
    }

    // the topic's icon, a plain no sign or check when the topic says nothing
    static func symbol(_ rule: CareRule) -> String {
        let topic = ReminderRow.topic(text: rule.title, quote: rule.quote)
        if topic == .other || topic == .medicines { return rule.isAllowed ? "checkmark.circle" : "nosign" }
        return topic.tileSymbol
    }

    private func subtitle(_ rule: CareRule, _ status: RuleStatus) -> String {
        switch status.kind {
        case .allowedLater, .notAllowedLater:
            return "From \(DayMath.shortDate(forDay: DoseSchedule.startDay(of: rule), from: surgeryDate))"
        case .ended:
            return DayMath.shortDate(forDay: rule.endDay ?? 0, from: surgeryDate)
        default:
            return RuleRow.reminderDetail(detail: status.detail, headline: status.headline)
        }
    }

    var spoken: String {
        groups.map { group in
            ([group.title + "."] + group.lines.map { "\($0.title). \($0.subtitle)." }).joined(separator: " ")
        }
        .joined(separator: " ")
    }
}

// one rule in its sheet
struct RuleDetail {
    let rule: CareRule
    let now: Date

    let title = "Rule"
    let doneButton = "Done"

    private var surgeryDate: Date { rule.plan?.surgeryDate ?? now }

    var eyebrow: String { rule.isAllowed ? "OK" : "Don\u{2019}t" }
    var eyebrowSymbol: String { rule.isAllowed ? "checkmark.circle" : "nosign" }
    var tone: Tone { rule.isAllowed ? .good : .stop }
    var heading: String { rule.title }
    var text: String { rule.condition }

    var fromText: String? {
        guard let start = rule.startDay, start > (rule.plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0) else { return nil }
        return DayMath.shortDate(forDay: start, from: surgeryDate)
    }
    var untilText: String? { rule.endDay.map { DayMath.shortDate(forDay: $0, from: surgeryDate) } }

    var quoteSource: String { PlainText.source(paper: rule.paper, page: rule.quotePage) }
    var quote: String { rule.quote.isEmpty ? "" : "\u{201C}\(rule.quote)\u{201D}" }
    var quotePlain: String { PaperAbbreviations.explain(rule.quote) }
}
