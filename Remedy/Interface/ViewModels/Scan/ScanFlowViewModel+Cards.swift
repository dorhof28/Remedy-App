//
//  ScanFlowViewModel+Cards.swift
//  Remedy
//
//  the cards shown on the confirm screen
//

import Foundation

extension ScanFlowViewModel {

    // the last given row on a medicine card
    private func lastGivenFact(for m: DraftMedicine) -> InfoRow? {
        let value: String
        switch lastGivenReading(for: m) {
        case .none:
            return nil
        case .time(let date):
            value = LastGivenParser.hospitalText(date)
        case .needsAmPm(let am, let pm):
            if let picked = m.lastGivenPick, picked == am || picked == pm {
                value = "In the hospital at \(DayMath.timeText(of: picked)) (your answer)"
            } else {
                value = "Your paper leaves out AM or PM, not used until you answer"
            }
        }
        return InfoRow(id: "lastgiven", label: "Last given", value: value)
    }

    // a confirm card for a medicine
    func card(for m: DraftMedicine, index: Int) -> ConfirmCard {
        let eyebrow: String
        let symbol: String
        let tone: Tone
        switch m.action {
        case .stop: eyebrow = "Stop taking"; symbol = "nosign"; tone = .stop
        case .take: eyebrow = "Every day"; symbol = "pill"; tone = .info
        case .takeAsNeeded: eyebrow = "Only when needed"; symbol = "clock"; tone = .info
        case .okToTake: eyebrow = "OK to take"; symbol = "checkmark.circle"; tone = .good
        }
        var title = m.name
        let otherNames = m.alsoKnownAs.filter { $0 != m.name.lowercased() }.prefix(2).map { PlainText.upperFirst($0) }
        if !otherNames.isEmpty && !m.isGroup { title += " (\(otherNames.joined(separator: ", ")))" }

        var facts: [InfoRow] = []
        var text = ""
        if m.action == .stop {
            text = "Don\u{2019}t take it until your surgeon says it\u{2019}s OK."
            if let start = m.startDay, let date = dayDate(start - 1) {
                facts.append(InfoRow(id: "last", label: "Last dose", value: DayMath.shortDate(date)))
            } else {
                facts.append(InfoRow(id: "when", label: "When", value: whenText(m.startDay, m.endDay)))
            }
        } else {
            if !m.amount.isEmpty { facts.append(InfoRow(id: "amount", label: "How much", value: m.amount)) }
            var when = ""
            if let hours = m.minHoursBetween { when = "Every \(hours) hours" }
            if !m.timesOfDay.isEmpty {
                let times = m.timesOfDay.sorted().map { DayMath.shortTimeText($0) }.joined(separator: ", ")
                when = when.isEmpty ? times : "\(when): \(times)"
            }
            if when.isEmpty { when = whenText(m.startDay, m.endDay) }
            facts.append(InfoRow(id: "when", label: "When", value: when))
            if !m.onlyIf.isEmpty { facts.append(InfoRow(id: "onlyif", label: "Only if", value: m.onlyIf)) }
            if let max = m.maxPerDay { facts.append(InfoRow(id: "max", label: "Most a day", value: "\(max)")) }
            if !m.reason.isEmpty { facts.append(InfoRow(id: "why", label: "For", value: PlainText.upperFirst(m.reason))) }
            if let end = m.endDay, let date = dayDate(end) {
                facts.append(InfoRow(id: "until", label: "Until", value: DayMath.shortDate(date)))
            }
        }
        if !m.exception.isEmpty { facts.append(InfoRow(id: "except", label: "Except", value: m.exception)) }
        if m.isGroup && !m.alsoKnownAs.isEmpty {
            facts.append(InfoRow(id: "includes", label: "Also", value: m.alsoKnownAs.prefix(6).map { PlainText.upperFirst($0) }.joined(separator: ", ")))
        }
        if let lastGiven = lastGivenFact(for: m) { facts.append(lastGiven) }

        return ConfirmCard(id: m.id, item: .medicine(index), eyebrow: eyebrow, symbol: symbol, tone: tone, title: title,
                           subtitle: m.strength, text: text, facts: facts, quote: m.quote,
                           quoteSource: sourceText(page: m.quotePage), plainWords: PaperAbbreviations.explain(m.quote))
    }

    // the real date of a day counted from surgery, nil until the surgery date is known
    private func dayDate(_ day: Int) -> Date? {
        guard let surgery = draft?.surgeryDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: day, to: surgery)
    }

    // a confirm card for a rule
    func card(for r: DraftRule, index: Int) -> ConfirmCard {
        var facts = [InfoRow(id: "when", label: "When", value: whenText(r.startDay, r.endDay))]
        if !r.condition.isEmpty { facts.append(InfoRow(id: "while", label: "Only while", value: r.condition)) }
        return ConfirmCard(id: r.id, item: .rule(index),
                           eyebrow: r.isAllowed ? "You may" : "Don\u{2019}t",
                           symbol: r.isAllowed ? "checkmark.circle.fill" : "hand.raised.fill",
                           tone: r.isAllowed ? .good : .stop, title: r.title, facts: facts,
                           quote: r.quote, quoteSource: sourceText(page: r.quotePage))
    }

    // a confirm card for a to-do
    func card(for t: DraftTask, index: Int) -> ConfirmCard {
        let due = t.dueDay.map { PlainText.upperFirst(DayMath.surgeryWords(forDay: $0)) } ?? "No date on the papers"
        return ConfirmCard(id: t.id, item: .task(index), eyebrow: "To do", symbol: "checklist", tone: .caution,
                           title: t.title, facts: [InfoRow(id: "due", label: "By", value: due)],
                           quote: t.quote, quoteSource: sourceText(page: t.quotePage))
    }

    // a confirm card for a visit
    func card(for a: DraftAppointment, index: Int) -> ConfirmCard {
        var facts = [InfoRow(id: "when", label: "When", value: "\(DayMath.longDate(a.date)), \(DayMath.timeText(of: a.date))")]
        if !a.place.isEmpty { facts.append(InfoRow(id: "where", label: "Where", value: a.place)) }
        if !a.doctor.isEmpty { facts.append(InfoRow(id: "who", label: "With", value: a.doctor)) }
        return ConfirmCard(id: a.id, item: .appointment(index), eyebrow: "Visit", symbol: "stethoscope", tone: .info,
                           title: a.title, facts: facts,
                           quote: a.quote, quoteSource: sourceText(page: a.quotePage))
    }

    // which days a rule or medicine covers
    private func whenText(_ start: Int?, _ end: Int?) -> String {
        switch (start, end) {
        case let (start?, end?):
            return "\(PlainText.upperFirst(DayMath.surgeryWords(forDay: start))) to \(DayMath.surgeryWords(forDay: end))"
        case let (start?, nil):
            return "From \(DayMath.surgeryWords(forDay: start))"
        case let (nil, end?):
            return "Until \(DayMath.surgeryWords(forDay: end))"
        case (nil, nil):
            return paper == .afterSurgery ? "From surgery day" : "Starting now"
        }
    }

    // "After-surgery papers page 1" or where an import came from
    private func sourceText(page: Int?) -> String {
        switch draft?.source {
        case .epic: return epicSource
        case .appleHealth: return healthSource
        default: return PlainText.source(paper: paper, page: page)
        }
    }

    // marks one draft item as matching the paper or not
    func setConfirmed(_ item: ConfirmItem, _ value: Bool) {
        switch item {
        case .medicine(let i): draft?.medicines[i].isConfirmed = value
        case .rule(let i): draft?.rules[i].isConfirmed = value
        case .task(let i): draft?.tasks[i].isConfirmed = value
        case .appointment(let i): draft?.appointments[i].isConfirmed = value
        }
    }
}
