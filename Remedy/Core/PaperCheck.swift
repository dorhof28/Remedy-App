//
//  PaperCheck.swift
//  Remedy
//
//  compares what different papers say about the same medicine
//

import Foundation

// one medicine line from one paper, built by PaperCheckInput
nonisolated struct CheckItem: Equatable {
    // index into PaperCheckInput.medicines
    var id: Int
    var paperID: UUID
    var source: PaperSource
    var field: PaperField?
    var printedDate: Date?
    var addedAt: Date
    var paperKind: PaperKind
    var doctorName: String?
    var name: String
    // normalized own name other names and brands
    var names: [String]
    var isGroup: Bool
    var groupMembers: [String]
    var isGeneric: Bool
    var action: MedicineAction
    var startDay: Int?
    var endDay: Int?
    var strength: String
    var amount: String
    var quote: String

    var isSurgeryTeam: Bool { source == .surgeryTeam }
    var isRecord: Bool { source == .hospitalRecord }
}

// how two papers' lines for the same medicine differ
nonisolated enum CheckKind: Equatable {
    case differentAction    // take vs stop
    case differentStopDay
    case differentDose
    case agree
    case notMentioned       // another doctor lists it, the surgery team's papers do not
}

// the color of a paper check card
nonisolated enum CheckColor: Equatable {
    case red      // papers disagree, ask the office
    case blue     // a newer paper replaced an older one
    case green    // papers agree
}

// which precedence rule decided the finding
nonisolated enum CheckRule: Equatable {
    case agree
    case noPrintedDate       // rule 2
    case genericNewer        // rule 3
    case sameTeam            // rule 4
    case surgeryTeamCovers   // rule 6, a newer surgery team paper is followed for the days it covers
    case muchLater           // rule 6 blue, printed a month or more later
    case differentDoctors    // rule 6 red, remedy does not pick
    case circle              // papers beat each other in a circle, none is followed until the patient picks
    case notMentioned        // only another doctor's paper lists it, a calm note to ask the surgeon's office
}

// papers about the same medicine, two or a circle of three or more
nonisolated struct Finding {
    // medicine plus every paper id sorted, the saved check note uses it
    let key: String
    let medicine: String
    let kind: CheckKind
    let color: CheckColor
    let rule: CheckRule
    // newer first, a circle has no newer so newest added first
    let items: [CheckItem]
    // blue, or red once a note picked one
    let winnerPaperID: UUID?
    // red pair, what reminders follow until resolved, nil for a circle
    let defaultPaperID: UUID?
    // red, the day before they first disagree, nil means ask now
    let askByDay: Int?
    // rule 5, the days the surgery team's line is the authority: up to surgery day for a pre-op paper,
    // from surgery day for a post-op one, nil for all days
    var period: DayRange? = nil

    var older: CheckItem { items[items.count - 1] }
    var newer: CheckItem { items[0] }
    var isCircle: Bool { rule == .circle }
    var isResolved: Bool { color == .red && winnerPaperID != nil }
    // a not mentioned note the patient marked as asked
    var isAsked: Bool { rule == .notMentioned && winnerPaperID != nil }

    // the line reminders don't follow and on which days, nil when both are followed or for a circle
    var notFollowed: (item: CheckItem, days: DayRange)? {
        guard !isCircle, rule != .notMentioned, color != .green, let followed = winnerPaperID ?? defaultPaperID else { return nil }
        // a group line still holds for its other members
        guard let item = [older, newer].first(where: { $0.paperID != followed }), !item.isGroup else { return nil }
        // a different stop day replaces the whole line, anything else only the shared days
        return (item, kind == .differentStopDay ? DayRange(start: item.startDay, end: item.endDay) : sharedDays)
    }

    // every line reminders don't follow, the days it is dropped and the days another line beats it
    // outside its period the surgery team's line steps aside and the other line is followed
    var notFollowedLines: [(item: CheckItem, days: DayRange, lostDays: DayRange)] {
        guard let line = notFollowed else { return [] }
        guard rule == .surgeryTeamCovers, let period else { return [(line.item, line.days, sharedDays)] }
        var result: [(item: CheckItem, days: DayRange, lostDays: DayRange)] = []
        if let days = line.days.intersection(period), let lost = sharedDays.intersection(period) {
            result.append((line.item, days, lost))
        }
        if let surgery = items.first(where: { $0.paperID == winnerPaperID }), !surgery.isGroup,
           let outside = sharedDays.intersection(period.outside) {
            result.append((surgery, outside, outside))
        }
        return result
    }

    // the paper the app follows on a day, nil for an open circle
    func followedPaperID(onDay day: Int) -> UUID? {
        let followed = winnerPaperID ?? defaultPaperID
        guard rule == .surgeryTeamCovers, let period, !period.contains(day), sharedDays.contains(day) else { return followed }
        return items.first { $0.paperID != followed }?.paperID ?? followed
    }

    // the days both lines cover
    var sharedDays: DayRange {
        DayRange(start: [older.startDay, newer.startDay].compactMap { $0 }.max(),
                 end: [older.endDay, newer.endDay].compactMap { $0 }.min())
    }
}

// plan days, nil ends are open
nonisolated struct DayRange: Equatable {
    var start: Int?
    var end: Int?

    func contains(_ day: Int) -> Bool { day >= (start ?? Int.min) && day <= (end ?? Int.max) }

    // the days in both, nil when none
    func intersection(_ other: DayRange) -> DayRange? {
        let low = [start, other.start].compactMap { $0 }.max()
        let high = [end, other.end].compactMap { $0 }.min()
        if let low, let high, low > high { return nil }
        return DayRange(start: low, end: high)
    }

    // the days after an up to range or before a from range, a period is only ever one of those
    var outside: DayRange {
        if let end, start == nil { return DayRange(start: end + 1, end: nil) }
        if let start, end == nil { return DayRange(start: nil, end: start - 1) }
        return DayRange(start: 0, end: -1)
    }
}

// everything the paper check found for a plan
nonisolated struct PaperCheckResult {
    // pairs, and circles in place of the pairs inside them
    let findings: [Finding]
    // record medicines no paper names
    let gaps: [CheckItem]
    // replaced item ids, blue losers and resolved red losers, on some of their days
    let losingItems: Set<Int>
    // item id to the days reminders don't follow it, blue losers, lines not followed while red
    // and every line of an open circle
    let notFollowedDays: [Int: [DayRange]]
}

// compares every pair of papers that mention the same medicine
nonisolated enum PaperCheck {

    static let gapText = "Not on your papers. Ask your care team."

    // notes are finding key to the chosen paper id
    static func run(_ items: [CheckItem], notes: [String: UUID] = [:]) -> PaperCheckResult {
        let papers = items.filter { !$0.isRecord }
        let named = items.filter { !$0.isGroup }
        let compared = papers.filter { !$0.isGroup } + papers.filter(\.isGroup).flatMap { expand($0, named: named) }

        var pairs: [Finding] = []
        for (index, first) in compared.enumerated() {
            for second in compared[(index + 1)...] {
                // two lines on one paper are one doctor's plan
                guard first.paperID != second.paperID, MedicineIdentity.same(first.names, second.names),
                      overlap(first, second) else { continue }
                pairs.append(finding(first, second, notes: notes))
            }
        }

        let gaps = items.filter { record in
            record.isRecord && !papers.contains { !$0.isGroup && MedicineIdentity.same($0.names, record.names) }
        }

        let (notFollowed, circles) = notFollowedDays(pairs, lines: compared, notes: notes)
        // a circle card shows every quote so the pairs inside it are not shown twice
        let findings = pairs.filter { pair in
            !circles.contains { circle in pair.items.allSatisfy { item in circle.items.contains { $0.id == item.id } } }
        } + circles + notMentioned(papers: papers, compared: compared, notes: notes)

        var losing = Set<Int>()
        for finding in findings where finding.winnerPaperID != nil {
            losing.formUnion(finding.notFollowedLines.map(\.item.id))
            if finding.isCircle {
                losing.formUnion(finding.items.filter { $0.paperID != finding.winnerPaperID }.map(\.id))
            }
        }
        return PaperCheckResult(findings: findings, gaps: gaps, losingItems: losing, notFollowedDays: notFollowed)
    }

    // the days each line is not followed, on a day every line of a medicine loses to another line
    // that also covers that day the papers beat each other in a circle, then no line is followed
    // on those days until the patient picks a paper, and then only that paper's lines
    private static func notFollowedDays(_ findings: [Finding], lines: [CheckItem],
                                        notes: [String: UUID]) -> ([Int: [DayRange]], [Finding]) {
        var dropped: [Int: [DayRange]] = [:]
        // only the days the line that beat it covers too
        var lost: [Int: [DayRange]] = [:]
        for finding in findings {
            for line in finding.notFollowedLines {
                dropped[line.item.id, default: []].append(line.days)
                lost[line.item.id, default: []].append(line.lostDays)
            }
        }
        // group lines are never dropped
        func isIn(_ days: [Int: [DayRange]], _ line: CheckItem, on day: Int) -> Bool {
            !line.isGroup && (days[line.id]?.contains { $0.contains(day) } ?? false)
        }

        var result: [Int: [DayRange]] = [:]
        var circleDays: [Int: [DayRange]] = [:]
        for id in dropped.keys.sorted() {
            guard let line = lines.first(where: { $0.id == id && !$0.isGroup }) else { continue }
            let same = lines.filter { MedicineIdentity.same($0.names, line.names) }
            // days where nothing changes between two edges
            let ranges = same.flatMap { [DayRange(start: $0.startDay, end: $0.endDay)] + (dropped[$0.id] ?? []) + (lost[$0.id] ?? []) }
            let edges = Set(ranges.flatMap { [$0.start, $0.end.map { $0 + 1 }] }.compactMap { $0 }).sorted()
            let pieces = edges.isEmpty ? [DayRange(start: nil, end: nil)]
                : [DayRange(start: nil, end: edges[0] - 1)]
                    + zip(edges, edges.dropFirst()).map { DayRange(start: $0, end: $1 - 1) }
                    + [DayRange(start: edges[edges.count - 1], end: nil)]
            for piece in pieces {
                let day = piece.start ?? piece.end ?? 0
                let allLost = same.allSatisfy { !DayRange(start: $0.startDay, end: $0.endDay).contains(day) || isIn(lost, $0, on: day) }
                guard isIn(dropped, line, on: day) else { continue }
                if allLost {
                    circleDays[id, default: []].append(piece)
                } else {
                    result[id, default: []].append(piece)
                }
            }
        }

        // one circle per medicine
        var groups: [[CheckItem]] = []
        for id in circleDays.keys.sorted() {
            guard let line = lines.first(where: { $0.id == id && !$0.isGroup }) else { continue }
            if let index = groups.firstIndex(where: { MedicineIdentity.same($0[0].names, line.names) }) {
                groups[index].append(line)
            } else {
                groups.append([line])
            }
        }
        let circles = groups.map { circle($0, notes: notes) }
        for circle in circles {
            for line in circle.items where line.paperID != circle.winnerPaperID {
                result[line.id, default: []] += circleDays[line.id] ?? []
            }
        }
        return (result, circles)
    }

    // another doctor's medicine no surgery team line names, even through a group line, one note per medicine
    // only when there is a surgery team paper, with none every paper is another doctor's
    private static func notMentioned(papers: [CheckItem], compared: [CheckItem], notes: [String: UUID]) -> [Finding] {
        let surgery = compared.filter(\.isSurgeryTeam)
        guard !surgery.isEmpty else { return [] }
        var groups: [[CheckItem]] = []
        for line in papers where !line.isSurgeryTeam && !line.isGroup
            && !surgery.contains(where: { MedicineIdentity.same($0.names, line.names) }) {
            if let index = groups.firstIndex(where: { MedicineIdentity.same($0[0].names, line.names) }) {
                groups[index].append(line)
            } else {
                groups.append([line])
            }
        }
        return groups.map { lines in
            let items = lines.sorted { isNewer($0, than: $1) }
            let ids = Set(items.map(\.paperID))
            let key = (["not mentioned", MedicineIdentity.key(items[0].names, items[0].names)] + ids.map(\.uuidString).sorted())
                .joined(separator: "|")
            // nothing disagrees so its own lines are followed, a note only marks it as asked
            return Finding(key: key, medicine: items[0].name, kind: .notMentioned, color: .blue, rule: .notMentioned,
                           items: items, winnerPaperID: notes[key].flatMap { ids.contains($0) ? $0 : nil },
                           defaultPaperID: items[0].paperID, askByDay: nil)
        }
    }

    // red until the patient picks one of its papers, no paper is followed before that
    private static func circle(_ lines: [CheckItem], notes: [String: UUID]) -> Finding {
        let items = lines.sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.id < $1.id }
        let papers = Set(items.map(\.paperID))
        let shared = Array(items.reduce(Set(items[0].names)) { $0.intersection($1.names) })
        let key = ([MedicineIdentity.key(shared, shared)] + papers.map(\.uuidString).sorted()).joined(separator: "|")
        let kinds = items.flatMap { first in items.map { kind(first, $0) } }
        let chosen = notes[key].flatMap { papers.contains($0) ? $0 : nil }
        return Finding(key: key, medicine: items[0].name,
                       kind: [CheckKind.differentAction, .differentStopDay].first { kinds.contains($0) } ?? .differentDose,
                       color: .red, rule: .circle, items: items, winnerPaperID: chosen, defaultPaperID: nil, askByDay: nil)
    }

    // a group line as one line per member the patient has
    private static func expand(_ group: CheckItem, named: [CheckItem]) -> [CheckItem] {
        group.groupMembers.compactMap { member in
            let names = MedicineIdentity.names(member, alsoKnownAs: [])
            guard let has = named.first(where: { MedicineIdentity.same($0.names, names) }) else { return nil }
            var line = group
            line.name = has.name
            line.names = names
            line.isGeneric = true
            return line
        }
    }

    // one finding for a pair, the older and newer paper decided by printed date
    private static func finding(_ first: CheckItem, _ second: CheckItem, notes: [String: UUID]) -> Finding {
        let (older, newer) = isNewer(first, than: second) ? (second, first) : (first, second)
        let ids = [older.paperID, newer.paperID].map(\.uuidString).sorted()
        let key = ([MedicineIdentity.key(older.names, newer.names)] + ids).joined(separator: "|")
        let kind = kind(older, newer)

        guard kind != .agree else {
            return Finding(key: key, medicine: older.name, kind: kind, color: .green, rule: .agree, items: [newer, older],
                           winnerPaperID: nil, defaultPaperID: nil, askByDay: nil)
        }
        let rule = rule(older, newer)
        // rule 6, a newer surgery team paper wins over another doctor's for the days it covers
        if rule == .surgeryTeamCovers {
            return Finding(key: key, medicine: older.name, kind: kind, color: .blue, rule: .surgeryTeamCovers,
                           items: [newer, older], winnerPaperID: newer.paperID, defaultPaperID: nil, askByDay: nil,
                           period: period(of: newer))
        }
        let isRed = [CheckRule.noPrintedDate, .genericNewer, .differentDoctors].contains(rule)
        guard isRed else {
            return Finding(key: key, medicine: older.name, kind: kind, color: .blue, rule: rule, items: [newer, older],
                           winnerPaperID: newer.paperID, defaultPaperID: nil, askByDay: nil)
        }

        // the surgery team while red, else the newer
        let fallback = older.isSurgeryTeam && !newer.isSurgeryTeam ? older : newer
        let chosen = notes[key].flatMap { [older.paperID, newer.paperID].contains($0) ? $0 : nil }
        return Finding(key: key, medicine: older.name, kind: kind, color: .red, rule: rule, items: [newer, older],
                       winnerPaperID: chosen, defaultPaperID: fallback.paperID,
                       askByDay: firstDifferentDay(older, newer, kind: kind).map { $0 - 1 })
    }

    // a pre-op paper applies before surgery and a post-op one after, both on surgery day
    // a line whose own days reach the other side, like a pre-op paper's days -10 to 10, covers all its days
    static func period(of surgery: CheckItem) -> DayRange? {
        switch surgery.paperKind {
        case .beforeSurgery:
            let staysBefore = (surgery.startDay ?? Int.min) <= 0 && (surgery.endDay ?? Int.min) <= 0
            return staysBefore ? DayRange(start: nil, end: 0) : nil
        case .afterSurgery:
            let staysAfter = (surgery.startDay ?? Int.max) >= 0 && (surgery.endDay ?? Int.max) >= 0
            return staysAfter ? DayRange(start: 0, end: nil) : nil
        }
    }

    // rule 2 no printed date, rule 3 a group line never beats a named one, then rule 6 (Core/NewerPaperRule):
    // the newer wins only from the surgery team or printed a calendar month or more later
    private static func rule(_ older: CheckItem, _ newer: CheckItem) -> CheckRule {
        guard older.printedDate != nil, newer.printedDate != nil else { return .noPrintedDate }
        if newer.isGeneric && !older.isGeneric { return .genericNewer }
        switch NewerPaperRule.decide(facts(older), facts(newer)) {
        case .newerWins(.fromSurgeryTeam): return older.isSurgeryTeam ? .sameTeam : .surgeryTeamCovers
        case .newerWins: return .muchLater
        case .ask: return .differentDoctors
        }
    }

    // the giver rule 6 needs, the surgery team covers the surgeon's office and the hospital
    static func facts(_ item: CheckItem) -> NewerPaperRule.PaperFacts {
        let giver: NewerPaperRule.Giver = item.isSurgeryTeam ? .surgeonsOffice : (item.source == .other ? .pharmacy : .anotherDoctor)
        return NewerPaperRule.PaperFacts(giver: giver, printed: item.printedDate)
    }

    // same office and field, or both from the surgery team
    static func sameTeam(_ first: CheckItem, _ second: CheckItem) -> Bool {
        (first.source == second.source && first.field == second.field) || (first.isSurgeryTeam && second.isSurgeryTeam)
    }

    // printed date then added date
    static func isNewer(_ first: CheckItem, than second: CheckItem) -> Bool {
        if let a = first.printedDate, let b = second.printedDate {
            let days = DayMath.dayOffset(of: a, from: b)
            if days != 0 { return days > 0 }
        }
        if first.addedAt != second.addedAt { return first.addedAt > second.addedAt }
        return first.paperID.uuidString > second.paperID.uuidString
    }

    // take vs stop first, then stop days, then dose
    static func kind(_ first: CheckItem, _ second: CheckItem) -> CheckKind {
        if (first.action == .stop) != (second.action == .stop) { return .differentAction }
        if daysDiffer(first, second) { return .differentStopDay }
        if differs(first.strength, second.strength) || differs(first.amount, second.amount) { return .differentDose }
        return .agree
    }

    // a stop's days always count, a take line's only when both papers give that day
    static func daysDiffer(_ first: CheckItem, _ second: CheckItem) -> Bool {
        if first.action == .stop {
            return first.startDay != second.startDay || first.endDay != second.endDay
        }
        return differs(first.startDay, second.startDay) || differs(first.endDay, second.endDay)
    }

    // only two known values that are not equal differ
    private static func differs(_ first: Int?, _ second: Int?) -> Bool {
        guard let first = first, let second = second else { return false }
        return first != second
    }

    // blank means the paper didn't say
    private static func differs(_ first: String, _ second: String) -> Bool {
        let a = first.lowercased().filter { !$0.isWhitespace }
        let b = second.lowercased().filter { !$0.isWhitespace }
        return !a.isEmpty && !b.isEmpty && a != b
    }

    // true when the two lines cover at least one day in common
    private static func overlap(_ first: CheckItem, _ second: CheckItem) -> Bool {
        let start = max(first.startDay ?? Int.min, second.startDay ?? Int.min)
        let end = min(first.endDay ?? Int.max, second.endDay ?? Int.max)
        return start <= end
    }

    // first day the two lines say different things, nil when already
    private static func firstDifferentDay(_ first: CheckItem, _ second: CheckItem, kind: CheckKind) -> Int? {
        guard kind == .differentStopDay else {
            // they disagree on every shared day
            let start = max(first.startDay ?? Int.min, second.startDay ?? Int.min)
            return start == Int.min ? nil : start
        }
        // same days as daysDiffer, a stop with no start is stopped already
        let isStop = first.action == .stop
        var days: [Int] = []
        if first.startDay != second.startDay {
            if let a = first.startDay, let b = second.startDay {
                days.append(min(a, b))
            } else if isStop {
                return nil
            }
        }
        if first.endDay != second.endDay {
            if let a = first.endDay, let b = second.endDay {
                days.append(min(a, b) + 1)
            } else if isStop, let end = first.endDay ?? second.endDay {
                days.append(end + 1)
            }
        }
        return days.min()
    }
}
