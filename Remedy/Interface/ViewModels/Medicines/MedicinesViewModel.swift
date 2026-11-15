//
//  MedicinesViewModel.swift
//  Remedy
//
//  medicines tab for both looks
//

import Foundation
import SwiftData

// MARK: - Sections

// the sections of the medicines tab, the patient can put them in any order
enum MedicineListSection: String, CaseIterable, Identifiable {
    case take = "take-today"
    case asNeeded = "as-needed"
    case paused = "paused"
    case allowed = "ok"
    case gaps = "gaps"
    case done = "done"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .take: return "Take today"
        case .asNeeded: return "As needed"
        case .paused: return "Paused"
        case .allowed: return "Allowed"
        case .gaps: return "Not on your papers"
        case .done: return "Finished"
        }
    }

    // the same symbol on the jump chip and the header
    var symbol: String {
        switch self {
        case .take: return "pill"
        case .asNeeded: return "clock"
        case .paused: return "pause.circle"
        case .allowed: return "checkmark.circle"
        case .gaps: return "questionmark.circle"
        case .done: return "checkmark.seal"
        }
    }

    var tone: Tone {
        switch self {
        case .take, .asNeeded: return .info
        case .paused, .gaps: return .caution
        case .allowed: return .good
        case .done: return .neutral
        }
    }

    // the icon tile of a row in this section
    var kind: ItemKind {
        switch self {
        case .take: return .medicine
        case .asNeeded: return .asNeeded
        case .paused: return .paused
        case .allowed: return .custom(symbol: "checkmark.circle", tone: .neutral)
        case .gaps: return .custom(symbol: "questionmark.circle", tone: .caution)
        case .done: return .custom(symbol: "checkmark.seal", tone: .neutral)
        }
    }

        // the default order, allowed before paused
    static let standard: [MedicineListSection] = [.take, .asNeeded, .allowed, .paused, .gaps, .done]
}

// MARK: - Display data

// one row in the list
struct MedicineRow: Identifiable {
    let medicine: MedicineInstruction
    let title: String           // "Eliquis (apixaban) 2.5 mg"
    let subtitle: String        // "8 AM taken · next 8 PM"
    let kind: ItemKind
    var hasDisagreement = false

    var id: PersistentIdentifier { medicine.persistentModelID }

    var spokenLabel: String {
        [title, subtitle].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// one section with its rows
struct MedicineSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tone: Tone              // colour of the section's header
    let rows: [MedicineRow]
    // only the not on your papers section has these
    var gaps: [MedicineGapRow] = []

    // the number on the right of the header
    var count: Int { rows.count + gaps.count }
    var spokenCount: String { "\(title), \(count) \(count == 1 ? "medicine" : "medicines")" }
}

// one record medicine no paper names
struct MedicineGapRow: Identifiable {
    let id: Int
    let name: String
    let detail: String
}

// the groups on screen 30 in the order they show
enum MedicineTabGroup: String, CaseIterable, Identifiable {
    case asNeeded, everyDay, stopped, notOnPapers, finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .asNeeded: return "Only when needed"
        case .everyDay: return "Every day"
        case .stopped: return "Stopped for now"
        case .notOnPapers: return "Not on your papers"
        case .finished: return "Finished"
        }
    }

    // the chip word, nil for groups with no chip
    var chipTitle: String? {
        switch self {
        case .asNeeded: return "If Needed"
        case .everyDay: return "Every Day"
        case .stopped: return "Stopped"
        case .notOnPapers: return nil
        case .finished: return "Finished"
        }
    }

    var chipSymbol: String {
        switch self {
        case .asNeeded: return "clock"
        case .everyDay: return "pills"
        case .stopped: return "nosign"
        case .notOnPapers: return "questionmark.circle"
        case .finished: return "checkmark.circle"
        }
    }

    // chips read every day first, the list shows when needed first
    static let chipOrder: [MedicineTabGroup] = [.everyDay, .asNeeded, .stopped, .finished]
}

// one row in the classic list or in search
struct MedicineLine: Identifiable {
    let id: String
    let medicine: MedicineInstruction?
    let symbol: String
    let tone: Tone
    let title: String
    let subtitle: String
    var subtitleTone: Tone = .neutral
    var opens: Bool { medicine != nil }
}

// a group of medicine rows under one title
struct MedicineLineGroup: Identifiable {
    let id: String
    let title: String
    let lines: [MedicineLine]
    var footer: String = ""
}

// a chip under the search field, nil group means all
struct MedicineChip: Identifiable {
    let group: MedicineTabGroup?
    let title: String
    let symbol: String?
    let count: Int

    var id: String { group?.rawValue ?? "all" }
    var label: String { "\(title) \(count)" }
}

// MARK: - ViewModel

// every medicine sorted into today's groups, one type both looks read
struct MedicinesViewModel {

    let plan: CarePlan?
    let now: Date

    // today as a plan day
    let day: Int

    // today's set-time doses
    private let todaySlots: [DoseSlot]
    // lines with an open papers-disagree card, they show first in their section
    private let disagreeing: Set<PersistentIdentifier>
    // two papers saying the same thing show as one row
    private let allMedicines: [MedicineInstruction]
    // those still followed, a replaced line never shows next to the one that replaced it
    private let followed: [MedicineInstruction]

    // the classic groups with their lines, empty ones too
    private(set) var groups: [MedicineTabGroup: [MedicineLine]] = [:]

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        let today = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
        self.day = today
        self.todaySlots = plan.map { DoseSchedule.slotsWithCheck(onDay: today, plan: $0, now: now) } ?? []
        let report = plan.map { PaperCheckReport.of($0) }
        let skipped = report?.skipped ?? SkippedLines()
        let repeated = report?.repeatedLines ?? []
        self.disagreeing = report?.openDisagreements ?? []
        let all = (plan?.medicines ?? []).filter { $0.isConfirmed && !repeated.contains($0.persistentModelID) }
        self.allMedicines = all
        self.followed = all.filter { medicine in
            let start = medicine.startDay ?? Int.min
            let end = medicine.endDay ?? Int.max
            let reference = end < today ? end : (start > today ? start : today)
            return !skipped.contains(medicine.persistentModelID, onDay: reference)
        }
        self.groups = buildGroups()
    }

    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    // MARK: - Words

    let title = "Medicines"
    let emptyDetail = "Medicines from your papers show up here after you scan them."
    let gapDetail = "Ask your care team if you should keep taking this."

    // gaps count too, so record-only plans still show them
    var isEmpty: Bool { allMedicines.isEmpty && gapRows.isEmpty }

    // record medicines no paper names
    var gapRows: [MedicineGapRow] {
        guard let plan else { return [] }
        return PaperCheckReport.of(plan).result.gaps.map { MedicineGapRow(id: $0.id, name: $0.name, detail: gapDetail) }
    }

    // MARK: - Sections (simple look, family sheets)

    // only the medicine sections that have medicines, in the standard order
    var sections: [MedicineSection] { allSections(sortByName: false).filter { !$0.rows.isEmpty } }

    // the sections in the patient's saved order, not on your papers included, empty ones left out
    func listSections(order saved: String = "", sortByName: Bool = false) -> [MedicineSection] {
        let byID = Dictionary(uniqueKeysWithValues: (allSections(sortByName: sortByName) + [gapSection]).map { ($0.id, $0) })
        return Self.decodeOrder(saved).compactMap { byID[$0.rawValue] }.filter { $0.count > 0 }
    }

    // the not on your papers section
    private var gapSection: MedicineSection {
        let section = MedicineListSection.gaps
        return MedicineSection(id: section.rawValue, title: section.title, symbol: section.symbol, tone: section.tone,
                               rows: [], gaps: gapRows)
    }

    // where the order is kept, one per patient
    static func orderKey(for plan: CarePlan?) -> String {
        "medicines.order.\(Int(plan?.createdAt.timeIntervalSince1970 ?? 0))"
    }

    // the saved order with any section it does not name added at the end
    static func decodeOrder(_ saved: String) -> [MedicineListSection] {
        var list: [MedicineListSection] = []
        for part in saved.split(separator: ",") {
            if let section = MedicineListSection(rawValue: String(part)), !list.contains(section) { list.append(section) }
        }
        return list + MedicineListSection.standard.filter { !list.contains($0) }
    }

    // every medicine section in the standard order, empty ones too
    private func allSections(sortByName: Bool) -> [MedicineSection] {
        var take: [MedicineRow] = []
        var asNeeded: [MedicineRow] = []
        var paused: [MedicineRow] = []
        var allowed: [MedicineRow] = []
        var done: [MedicineRow] = []
        // stopped now first, then stopping soon, then the ones that start again later
        var startsLater: [MedicineRow] = []
        for entry in orderedGroups {
            let medicines = entry.items.map { followed[$0.id] }
            switch entry.group {
            case .takeToday:
                take += medicines.filter { $0.action == .take }.map(dailyRow)
                asNeeded += medicines.filter { $0.action == .takeAsNeeded }.map(asNeededRow)
            case .dontTake, .stopSoon:
                paused += medicines.map(pausedRow)
            case .okToTake:
                // a take line that has not started yet is paused until then
                for medicine in medicines {
                    if medicine.action == .okToTake { allowed.append(allowedRow(medicine)) } else { startsLater.append(laterRow(medicine)) }
                }
            case .done:
                done += medicines.map(doneRow)
            }
        }
        paused += startsLater

        func section(_ kind: MedicineListSection, _ rows: [MedicineRow]) -> MedicineSection {
            MedicineSection(id: kind.rawValue, title: kind.title, symbol: kind.symbol, tone: kind.tone,
                            rows: arrange(rows, byName: sortByName))
        }
        return [section(.take, take), section(.asNeeded, asNeeded), section(.allowed, allowed),
                section(.paused, paused), section(.done, done)]
    }

    // the followed medicines in Core's groups, shared by the classic and simple builders
    private var orderedGroups: [(group: MedicineGroup, items: [MedicineOrderItem])] {
        let items = followed.enumerated().map { index, medicine in
            MedicineOrderItem(id: index, action: medicine.action, startDay: medicine.startDay, endDay: medicine.endDay,
                              nextDue: nextDue(of: medicine), name: MedicineText.everydayName(medicine))
        }
        return MedicineOrder.groups(items, today: day).map { (group: $0.group, items: $0.items) }
    }

    // a medicine whose papers disagree first, then by name when picked, else the order Core gave
    private func arrange(_ rows: [MedicineRow], byName: Bool) -> [MedicineRow] {
        let sorted = byName ? rows.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } : rows
        return sorted.filter(\.hasDisagreement) + sorted.filter { !$0.hasDisagreement }
    }

    // when the next dose is due, a missed one first
    private func nextDue(of medicine: MedicineInstruction) -> Date? {
        if medicine.action == .takeAsNeeded {
            let status = DoseSchedule.asNeededStatus(for: medicine, now: now)
            if status.reachedMax { return nil }
            return status.nextAllowed ?? now
        }
        return nextOpenSlot(for: medicine)?.scheduledFor
    }

    // today's doses not answered yet
    private func openSlots(for medicine: MedicineInstruction) -> [DoseSlot] {
        todaySlots.filter { $0.medicine.persistentModelID == medicine.persistentModelID && $0.log == nil && !$0.givenInHospital }
    }

    // dose a quick action logs, missed or due first then next
    private func nextOpenSlot(for medicine: MedicineInstruction) -> DoseSlot? {
        let open = openSlots(for: medicine)
        return open.first { $0.state == .missed || $0.state == .due } ?? open.first
    }

    // MARK: - Simple row builders

    // the section's look, a disagreement swaps the tile for a warning and says so in words
    private func row(_ medicine: MedicineInstruction, in section: MedicineListSection, detail: String) -> MedicineRow {
        let disagrees = disagreeing.contains(medicine.persistentModelID)
        let kind: ItemKind = disagrees ? .custom(symbol: Self.disagreeSymbol, tone: .stop) : section.kind
        let line = disagrees ? ([Self.disagreeWords, detail].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")) : detail
        return MedicineRow(medicine: medicine, title: MedicineText.fullName(everyday: medicine), subtitle: line,
                           kind: kind, hasDisagreement: disagrees)
    }

    static let disagreeWords = "Papers disagree"
    static let disagreeSymbol = "exclamationmark.triangle"

    // "8 AM taken · next 8 PM", "Missed 8 AM", "Both taken today"
    private func dailyRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let slots = todaySlots.filter { $0.medicine.persistentModelID == medicine.persistentModelID }
        let taken = slots.filter { $0.state == .taken }
        let missed = slots.first { $0.state == .missed }
        let next = slots.first { $0.state == .due || $0.state == .upcoming }
        var parts: [String] = []
        if let missed {
            parts.append("Missed \(DayMath.shortTimeText(missed.minute))")
        } else if let last = taken.last {
            parts.append("\(DayMath.shortTimeText(last.minute)) taken")
        } else if !medicine.amount.isEmpty, next != nil {
            parts.append(medicine.amount)
        }
        if let next {
            let time = DayMath.shortTimeText(next.minute)
            parts.append(parts.isEmpty ? (next.state == .due ? "Due \(time)" : "Next \(time)") : (next.state == .due ? "due \(time)" : "next \(time)"))
        } else if missed == nil, !slots.isEmpty, taken.count == slots.count {
            parts = [slots.count == 1 ? "Taken today" : "All \(slots.count) taken today"]
        }
        if parts.isEmpty {
            parts = [[medicine.amount, MedicineText.timesText(medicine)].filter { !$0.isEmpty }.joined(separator: " at ")]
        }
        return row(medicine, in: .take, detail: parts.joined(separator: " \u{00B7} "))
    }

    // "OK now · 2 left today", "OK from 6:40 PM · 4 left today"
    private func asNeededRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let status = DoseSchedule.asNeededStatus(for: medicine, now: now)
        let left = medicine.maxPerDay.map { "\(max(0, $0 - status.takenToday)) left today" }
        let detail: String
        if status.reachedMax {
            detail = "No more today"
        } else if let next = status.nextAllowed {
            detail = ["OK from \(DayMath.timeText(of: next))", left].compactMap { $0 }.joined(separator: " \u{00B7} ")
        } else {
            detail = ["OK now", left].compactMap { $0 }.joined(separator: " \u{00B7} ")
        }
        return row(medicine, in: .asNeeded, detail: detail)
    }

    // "Restart Dec 3", "Last dose Wednesday", "Stop today"
    private func pausedRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let detail: String
        if let start = medicine.startDay, start > day {
            detail = "Last dose \(dayWords(start - 1))"
        } else if let end = medicine.endDay {
            detail = "Restart \(dayWords(end + 1))"
        } else if medicine.startDay == day {
            detail = "Stop today"
        } else {
            detail = "Until your surgeon says it\u{2019}s OK"
        }
        return row(medicine, in: .paused, detail: detail)
    }

    // a take line that starts on a later day, "Restart Dec 3" when the same medicine is stopped first
    private func laterRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let start = medicine.startDay ?? day
        let names = Set(MedicineMatcher.names(of: medicine))
        let restarts = allMedicines.contains { $0.action == .stop && !names.isDisjoint(with: MedicineMatcher.names(of: $0)) }
        return row(medicine, in: .paused, detail: "\(restarts ? "Restart" : "Starts") \(dayWords(start))")
    }

    // "If you have pain", "Until Dec 3"
    private func allowedRow(_ medicine: MedicineInstruction) -> MedicineRow {
        var parts: [String] = []
        if !medicine.onlyIf.isEmpty { parts.append("If \(PlainText.lowerFirst(medicine.onlyIf))") }
        if let end = medicine.endDay { parts.append("Until \(dayWords(end))") }
        if parts.isEmpty { parts.append("Allowed now") }
        return row(medicine, in: .allowed, detail: parts.joined(separator: " \u{00B7} "))
    }

    // "Finished Nov 20"
    private func doneRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let end = medicine.endDay ?? day
        let word = medicine.action == .stop ? "Restarted" : "Finished"
        let when = medicine.action == .stop ? end + 1 : end
        return row(medicine, in: .done, detail: "\(word) \(dayWords(when))")
    }

    // calendar words, never day counters: "today", "tomorrow", "Wednesday", "Dec 3"
    private func dayWords(_ planDay: Int) -> String {
        SimpleWording.dayWord(for: DayMath.date(forDay: planDay, from: surgeryDate), now: now)
    }

    // MARK: - Classic tab

    let emptyTitle = "No Papers Yet"
    let emptyText = "Add your hospital papers to see your medicines."
    let addPapersButton = "Add Papers"
    let addMedicineButton = "Add Medicine"
    let noMatchTitle = "Not in your papers"
    let askButton = "Ask"
    let callOfficeButton = "Call Your Doctor\u{2019}s Office"

    func noMatchText(_ query: String) -> String {
        "\u{201C}\(query.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D} isn\u{2019}t on your papers. Ask before you take it."
    }

    var isListEmpty: Bool { groups.values.allSatisfy(\.isEmpty) }

    var allCount: Int { MedicineTabGroup.allCases.filter { $0 != .notOnPapers }.reduce(0) { $0 + (groups[$1]?.count ?? 0) } }

    // "All 7", then a chip per group, an empty group keeps its chip so the row never jumps
    var chips: [MedicineChip] {
        [MedicineChip(group: nil, title: "All", symbol: nil, count: allCount)]
            + MedicineTabGroup.chipOrder.compactMap { group in
                group.chipTitle.map { MedicineChip(group: group, title: $0, symbol: group.chipSymbol, count: groups[group]?.count ?? 0) }
            }
    }

    // the groups with rows, only the picked one when a chip is picked
    func shown(_ filter: MedicineTabGroup?) -> [MedicineLineGroup] {
        MedicineTabGroup.allCases
            .filter { filter == nil || $0 == filter }
            .compactMap { group in
                guard let lines = groups[group], !lines.isEmpty else { return nil }
                return MedicineLineGroup(id: group.rawValue, title: group.title, lines: lines)
            }
    }

    // the care team's number for the no match buttons
    var officeCall: URL? {
        plan?.contacts.first { $0.role == .careTeam && !$0.phone.isEmpty }.flatMap { DayMath.phoneURL($0.phone) }
    }

    // MARK: - Search ("Can I take...?")

    func isSearching(_ query: String) -> Bool { MedicineSearch.clean(query).count >= 2 }

    // matches by group, then what the plan has for a plain word like pain
    func search(_ query: String) -> [MedicineLineGroup] {
        var result: [MedicineLineGroup] = []
        var shownIDs = Set<String>()
        var matchedStops: [MedicineInstruction] = []
        for group in MedicineTabGroup.allCases where group != .notOnPapers {
            var lines: [MedicineLine] = []
            for line in groups[group] ?? [] {
                guard let medicine = line.medicine,
                      let hit = MedicineSearch.match(query, names: Self.searchNames(medicine)) else { continue }
                lines.append(Self.renamed(line, matched: hit, medicine: medicine))
                if group == .stopped { matchedStops.append(medicine) }
            }
            guard !lines.isEmpty else { continue }
            shownIDs.formUnion(lines.map(\.id))
            let footer = group == .stopped
                ? (MedicineSearch.kindSentence(for: query, page: matchedStops.first?.quotePage) ?? "") : ""
            result.append(MedicineLineGroup(id: group.rawValue, title: group.title, lines: lines, footer: footer))
        }
        // a plain word, or a stopped pain pill, shows what the plan has instead
        let painTopic = MedicineSearch.topics.first
        let stoppedPain = painTopic.map { topic in matchedStops.contains { MedicineSearch.isMember(Self.searchNames($0), of: topic) } } ?? false
        if let topic = MedicineSearch.topic(for: query) ?? (stoppedPain ? painTopic : nil) {
            let active = (groups[.asNeeded] ?? []) + (groups[.everyDay] ?? [])
            let lines = active.filter { line in
                guard let medicine = line.medicine, !shownIDs.contains(line.id) else { return false }
                return MedicineSearch.isMember(Self.searchNames(medicine), of: topic)
            }
            if !lines.isEmpty { result.append(MedicineLineGroup(id: "topic", title: topic.header, lines: lines)) }
        }
        return result
    }

    private static func searchNames(_ medicine: MedicineInstruction) -> [String] {
        MedicineSearch.names(name: medicine.name, alsoKnownAs: medicine.alsoKnownAs, isGroup: medicine.isGroup)
    }

    // "Advil (ibuprofen)" when a brand matched
    private static func renamed(_ line: MedicineLine, matched: String, medicine: MedicineInstruction) -> MedicineLine {
        // a group line keeps its own name, "Any other NSAID", so a brand never shows twice
        let generic = MedicineIdentity.brands.first { $0.contains(matched) }?.first
        guard !MedicineSearch.isGroupLine(name: medicine.name, isGroup: medicine.isGroup),
              let generic, matched != generic else { return line }
        let strength = medicine.strength.isEmpty ? "" : " \(medicine.strength)"
        return MedicineLine(id: line.id, medicine: medicine, symbol: line.symbol, tone: line.tone,
                            title: "\(matched.capitalized) (\(generic))\(medicine.isGroup ? "" : strength)",
                            subtitle: line.subtitle, subtitleTone: line.subtitleTone)
    }

    // "twice a day", "3 times a day"
    static func howOften(_ count: Int) -> String {
        switch count {
        case 0: return ""
        case 1: return "once a day"
        case 2: return "twice a day"
        default: return "\(count) times a day"
        }
    }

    // "You can take 1 now" from "1 tablet", else "You can take one now"
    static func takeNowText(_ amount: String) -> String {
        let number = amount.prefix { $0.isNumber }
        return number.isEmpty ? "You can take one now" : "You can take \(number) now"
    }

    // MARK: - Classic lines

    // every followed medicine in its group, then the ones no paper names
    private func buildGroups() -> [MedicineTabGroup: [MedicineLine]] {
        var groups: [MedicineTabGroup: [MedicineLine]] = [:]
        for entry in orderedGroups {
            for item in entry.items {
                let medicine = followed[item.id]
                let (group, line) = line(medicine, in: entry.group, disagrees: disagreeing.contains(medicine.persistentModelID))
                groups[group, default: []].append(line)
            }
        }
        // a medicine whose papers disagree goes first in its group
        for (group, lines) in groups {
            groups[group] = lines.filter { $0.symbol == Self.disagreeSymbol } + lines.filter { $0.symbol != Self.disagreeSymbol }
        }
        if plan != nil {
            groups[.notOnPapers] = gapRows.map { gap in
                MedicineLine(id: "gap-\(gap.id)", medicine: nil, symbol: "questionmark.circle", tone: .caution,
                             title: gap.name, subtitle: gap.detail)
            }
        }
        return groups
    }

    // one row: its group, subtitle and color for today
    private func line(_ medicine: MedicineInstruction, in order: MedicineGroup, disagrees: Bool) -> (MedicineTabGroup, MedicineLine) {
        let id = "\(medicine.persistentModelID.hashValue)"
        let title = MedicineText.fullName(everyday: medicine)
        func date(_ planDay: Int) -> String { DayMath.shortDate(forDay: planDay, from: surgeryDate) }
        func make(_ group: MedicineTabGroup, _ symbol: String, _ tone: Tone, _ subtitle: String, _ subTone: Tone = .neutral)
            -> (MedicineTabGroup, MedicineLine) {
            // an open disagreement is said in words and with a warning icon, never colour alone
            if disagrees {
                return (group, MedicineLine(id: id, medicine: medicine, symbol: Self.disagreeSymbol, tone: .stop, title: title,
                                            subtitle: "\(Self.disagreeWords) \u{00B7} \(subtitle)", subtitleTone: .stop))
            }
            return (group, MedicineLine(id: id, medicine: medicine, symbol: symbol, tone: tone, title: title,
                                        subtitle: subtitle, subtitleTone: subTone))
        }

        switch order {
        case .takeToday where medicine.action == .takeAsNeeded:
            let status = DoseSchedule.asNeededStatus(for: medicine, now: now)
            if status.reachedMax { return make(.asNeeded, "clock", .caution, "No more today", .caution) }
            if let next = status.nextAllowed { return make(.asNeeded, "clock", .info, "Next one at \(DayMath.timeText(of: next))") }
            return make(.asNeeded, "checkmark.circle", .good, Self.takeNowText(medicine.amount))
        case .takeToday:
            let often = Self.howOften(medicine.timesOfDay.count)
            let open = openSlots(for: medicine)
            let lead: String
            if let missed = open.first(where: { $0.state == .missed }) {
                lead = "Missed \(DayMath.timeText(of: missed.scheduledFor))"
            } else if let due = open.first(where: { $0.state == .due }) {
                lead = "Due now \u{00B7} \(DayMath.timeText(of: due.scheduledFor))"
            } else if let next = open.first {
                lead = "Next at \(DayMath.timeText(of: next.scheduledFor))"
            } else if medicine.timesOfDay.isEmpty {
                lead = "Every day"
            } else {
                lead = "Done for today"
            }
            let subtitle = [lead, often].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
            return make(.everyDay, "pills", .info, subtitle, lead.hasPrefix("Missed") ? .caution : .neutral)
        case .okToTake where medicine.action == .okToTake:
            let words = medicine.onlyIf.isEmpty ? "Keep taking your usual dose" : "Only if \(PlainText.lowerFirst(medicine.onlyIf))"
            return make(.everyDay, "pills", .info, words)
        case .okToTake:
            // a take line that starts on a later day
            return make(medicine.action == .takeAsNeeded ? .asNeeded : .everyDay, "calendar", .info,
                        "Starts \(date(medicine.startDay ?? day))")
        case .dontTake:
            let words = medicine.endDay.map { "Don\u{2019}t take until \(date($0 + 1))" } ?? "Don\u{2019}t take until surgeon says OK"
            return make(.stopped, "nosign", .stop, words, .stop)
        case .stopSoon:
            return make(.stopped, "nosign", .stop, "Last dose \(date((medicine.startDay ?? day) - 1))", .caution)
        case .done:
            let end = medicine.endDay ?? day
            let words = medicine.action == .stop ? "OK again since \(date(end + 1))" : "Finished \(date(end))"
            return make(.finished, "checkmark.circle", .neutral, words)
        }
    }
}

// MARK: - Open disagreements

extension PaperCheckReport {
    // every line in a red finding nobody has sorted out yet
    var openDisagreements: Set<PersistentIdentifier> {
        var ids = Set<PersistentIdentifier>()
        for finding in result.findings where finding.color == .red && !finding.isResolved {
            for item in finding.items where medicines.indices.contains(item.id) {
                ids.insert(medicines[item.id].persistentModelID)
            }
        }
        return ids
    }
}

// MARK: - Names

extension MedicineText {
    // "Eliquis (apixaban) 2.5 mg", everyday name first with the strength
    static func fullName(everyday medicine: some MedicineFacts) -> String {
        let name = everydayName(medicine)
        if medicine.strength.isEmpty || name.contains(medicine.strength) { return name }
        return "\(name) \(medicine.strength)"
    }
}

// MARK: - What a verdict looks like (shared by every medicine screen)

extension VerdictKind {
    var tone: Tone {
        switch self {
        case .dontTake, .stopSoon: return .caution
        case .stopEnded, .finished, .startsLater: return .neutral
        case .okToTake: return .good
        case .take, .asNeeded: return .info
        }
    }

    var symbol: String {
        switch self {
        case .dontTake, .stopSoon: return "pause.circle"
        case .stopEnded: return "arrow.uturn.backward.circle"
        case .okToTake: return "checkmark.circle"
        case .take: return "pill"
        case .asNeeded: return "clock"
        case .startsLater: return "calendar"
        case .finished: return "checkmark.seal"
        }
    }

}
