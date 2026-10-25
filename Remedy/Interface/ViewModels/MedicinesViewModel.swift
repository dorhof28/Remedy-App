//
//  MedicinesViewModel.swift
//  Remedy
//
//  medicines tab for both looks
//

import Foundation
import SwiftData

// MARK: - Display data

// one row in the list
struct MedicineRow: Identifiable {
    let medicine: MedicineInstruction
    let title: String           // "Ibuprofen (Advil)"
    let subtitle: String        // "Stopped since Thu, Oct 22"
    var trailingCaption: String = ""   // small grey word above `trailing` ("Next")
    let trailing: String        // "in 3 days" / "2:00 PM" ("" = none)
    let tone: Tone
    let symbol: String          // icon when we don't know what the pill looks like
    let swipeTitle: String      // "Take" / "Took one" ("" = no swipe action)

    var id: PersistentIdentifier { medicine.persistentModelID }
    var pillShape: String { medicine.pillShape }
    var pillColor: String { medicine.pillColor }

    var spokenLabel: String {
        [title, subtitle, trailing].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// one card with its rows
struct MedicineSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tone: Tone              // colour of the card's header
    let footer: String          // "" = none
    var startsExpanded: Bool = true
    let rows: [MedicineRow]

    // the number on the right of the header
    var countText: String { "\(rows.count)" }
}

// one answer under the search box
struct MedicineSearchResult: Identifiable {
    let medicine: MedicineInstruction
    let title: String           // "Advil → Ibuprofen"
    let headline: String        // "Don't take"
    let sentence: String        // "Stopped since..."
    let tone: Tone
    let symbol: String

    var id: PersistentIdentifier { medicine.persistentModelID }
}

// MARK: - ViewModel

struct MedicinesViewModel {

    let plan: CarePlan?
    let now: Date

    // today as a plan day
    let day: Int

    // today's set-time doses
    private let todaySlots: [DoseSlot]

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        let today = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
        self.day = today
        self.todaySlots = plan.map { DoseSchedule.slots(onDay: today, plan: $0, now: now) } ?? []
    }

    private var surgeryDate: Date { plan?.surgeryDate ?? now }
    private var isAfterSurgery: Bool { SurgeryPhase.forDay(day) == .afterSurgery }

    private var allMedicines: [MedicineInstruction] {
        (plan?.medicines ?? []).filter { $0.isConfirmed }
    }

    // MARK: - Words

    let title = "Medicines"
    let searchPrompt = "Can I take…? Type a medicine"
    let searchHeader = "From your papers"
    let searchFooter = "Matches brand names too, like Advil, Aleve or fish oil."
    let searchSymbol = "doc.text.magnifyingglass"
    let emptyTitle = "No medicines yet"
    let emptyDetail = "Medicines from your papers show up here after you scan them."

    var isEmpty: Bool { allMedicines.isEmpty }

    // under the last section so the real dates make sense
    var datesFootnote: String {
        guard plan?.surgeryDate != nil else { return "Add your surgery date on Today to see real dates." }
        return "Dates are counted from your surgery on \(DayMath.longDate(surgeryDate))."
    }

    // MARK: - Sections

    var sections: [MedicineSection] {
        let list = isAfterSurgery ? afterSections : beforeSections
        return list.filter { !$0.rows.isEmpty }
    }

    private var beforeSections: [MedicineSection] {
        let stops = medicines(.stop)
        let stopToday = stops.filter { $0.startDay == day }
        let stopped = stops.filter { DoseSchedule.isActive($0, on: day) && ($0.startDay ?? Int.min) < day }
        let soon = stops
            .filter { ($0.startDay ?? Int.min) > day }
            .sorted { ($0.startDay ?? 0) < ($1.startDay ?? 0) }
        let okay = medicines(.okToTake).filter { DoseSchedule.isActive($0, on: day) }
        let later = allMedicines.filter {
            ($0.action == .take || $0.action == .takeAsNeeded) && ($0.startDay ?? Int.min) > day
        }

        var result: [MedicineSection] = []
        result.append(MedicineSection(id: "stop-today", title: "Stop today", symbol: "exclamationmark.circle", tone: .stop,
                                      footer: "", rows: stopToday.map(verdictRow)))
        result.append(MedicineSection(id: "stopped", title: "Don\u{2019}t take", symbol: "nosign", tone: .stop,
                                      footer: "Until your surgeon says it\u{2019}s OK.", rows: stopped.map(verdictRow)))
        result.append(MedicineSection(id: "soon", title: "Stop soon", symbol: "calendar.badge.exclamationmark", tone: .caution,
                                      footer: "", rows: soon.map(stopSoonRow)))
        result.append(MedicineSection(id: "ok", title: "OK to take", symbol: "checkmark.circle", tone: .good,
                                      footer: "", rows: okay.map(verdictRow)))
        result.append(MedicineSection(id: "later", title: "Starts after surgery", symbol: "calendar", tone: .neutral,
                                      footer: "From your after-surgery papers.", startsExpanded: false, rows: later.map(verdictRow)))
        return result
    }

    private var afterSections: [MedicineSection] {
        let daily = medicines(.take)
            .filter { DoseSchedule.isActive($0, on: day) }
            .sorted { ($0.timesOfDay.min() ?? 0) < ($1.timesOfDay.min() ?? 0) }
        let asNeeded = medicines(.takeAsNeeded).filter { DoseSchedule.isActive($0, on: day) }
        let dontTake = medicines(.stop).filter { DoseSchedule.isActive($0, on: day) }
        let okay = medicines(.okToTake).filter { DoseSchedule.isActive($0, on: day) }
        // finished the most recently finished first
        let finished = allMedicines
            .filter { day > ($0.endDay ?? Int.max) }
            .sorted { ($0.endDay ?? 0) > ($1.endDay ?? 0) }

        var result: [MedicineSection] = []
        result.append(MedicineSection(id: "as-needed", title: "Only when needed", symbol: "hourglass", tone: .neutral,
                                      footer: "Open one to see when you can take the next dose.", rows: asNeeded.map(asNeededRow)))
        result.append(MedicineSection(id: "daily", title: "Every day · earliest first", symbol: "clock", tone: .neutral,
                                      footer: "", rows: daily.map(dailyRow)))
        result.append(MedicineSection(id: "dont", title: "Stopped for now", symbol: "nosign", tone: .stop,
                                      footer: "These still apply until your surgeon says otherwise.", rows: dontTake.map(verdictRow)))
        result.append(MedicineSection(id: "ok", title: "OK to take", symbol: "checkmark.circle", tone: .good,
                                      footer: "", rows: okay.map(verdictRow)))
        result.append(MedicineSection(id: "finished", title: "Finished", symbol: "checkmark.seal", tone: .neutral,
                                      footer: "", startsExpanded: false, rows: finished.map(verdictRow)))
        return result
    }

    // MARK: - Search ("Can I take...?")

    // true when the box has enough letters to search
    func isSearching(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    // can i take search
    func searchResults(for query: String) -> [MedicineSearchResult] {
        MedicineMatcher.matches(forSearch: query, medicines: allMedicines, today: day).map { match in
            let medicine = match.medicine
            let verdict = MedicineMatcher.verdict(for: medicine, today: day, surgeryDate: surgeryDate)
            let isOtherName = match.matchedName != medicine.name.lowercased()
            let title = isOtherName ? "\(match.matchedName.capitalized) → \(medicine.name)" : medicine.name
            return MedicineSearchResult(medicine: medicine, title: title, headline: verdict.headline,
                                        sentence: verdict.sentence, tone: verdict.kind.tone, symbol: verdict.kind.symbol)
        }
    }

    // shown when nothing matches
    func noMatchText(for query: String) -> String {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\u{201C}\(name)\u{201D} isn\u{2019}t on your papers. Ask your surgeon or pharmacist before you take it."
    }

    // MARK: - Swipe action

    // "Take" or "Took one"
    func swipe(_ row: MedicineRow, in context: ModelContext) {
        let medicine = row.medicine
        if medicine.action == .takeAsNeeded {
            if DoseSchedule.asNeededStatus(for: medicine, now: now).canTakeNow {
                DoseActions.logAsNeeded(medicine, now: now, in: context)
            }
            return
        }
        if let slot = nextOpenSlot(for: medicine) {
            DoseActions.log(medicine, scheduledFor: slot.scheduledFor, as: .taken, now: now, in: context)
        }
    }

    // MARK: - Row builders

    private func medicines(_ action: MedicineAction) -> [MedicineInstruction] {
        allMedicines.filter { $0.action == action }
    }

    // a row whose subtitle is the plain verdict
    private func verdictRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let verdict = MedicineMatcher.verdict(for: medicine, today: day, surgeryDate: surgeryDate)
        return MedicineRow(medicine: medicine, title: MedicineText.everydayName(medicine),
                           subtitle: shortVerdict(medicine, verdict: verdict), trailing: "",
                           tone: verdict.kind.tone, symbol: verdict.kind.symbol, swipeTitle: "")
    }

    // "Stop Wed Oct 28 · 1 day before surgery" "in 3 days"
    private func stopSoonRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let start = medicine.startDay ?? day
        return MedicineRow(medicine: medicine, title: MedicineText.everydayName(medicine),
                           subtitle: "Stop \(DayMath.shortDate(forDay: start, from: surgeryDate)) · \(DayMath.surgeryWords(forDay: start))",
                           trailing: DayMath.relative(daysFromToday: start - day),
                           tone: .caution, symbol: "calendar.badge.exclamationmark", swipeTitle: "")
    }

    // "8 AM · 8 PM · 1 tablet" "1 of 2 today"
    private func dailyRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let slots = todaySlots.filter { $0.medicine.persistentModelID == medicine.persistentModelID }
        let taken = slots.filter { $0.state == .taken }.count
        let hasMissed = slots.contains { $0.state == .missed }
        let subtitle = [medicine.amount, MedicineText.timesText(medicine)].filter { !$0.isEmpty }.joined(separator: " · ")

        // right side "Missed" / "Next 2:00 PM" / "Done today"
        let caption: String
        let trailing: String
        if hasMissed {
            caption = ""
            trailing = "Missed one"
        } else if let next = slots.first(where: { $0.state == .due || $0.state == .upcoming }) {
            caption = next.state == .due ? "Due" : "Next"
            trailing = DayMath.timeText(next.minute)
        } else {
            caption = ""
            trailing = "\(taken) of \(slots.count) today"
        }

        return MedicineRow(medicine: medicine, title: MedicineText.everydayName(medicine),
                           subtitle: subtitle, trailingCaption: caption, trailing: trailing,
                           tone: hasMissed ? .stop : .info, symbol: "pills.fill",
                           swipeTitle: nextOpenSlot(for: medicine) == nil ? "" : "Take")
    }

    // "Only for severe pain" "OK now" / "Next at 3:20 PM"
    private func asNeededRow(_ medicine: MedicineInstruction) -> MedicineRow {
        let status = DoseSchedule.asNeededStatus(for: medicine, now: now)
        let state: String
        if status.reachedMax {
            state = "No more today"
        } else if let next = status.nextAllowed {
            state = "Next at \(DayMath.timeText(of: next))"
        } else {
            state = "OK now"
        }
        let subtitle = medicine.onlyIf.isEmpty ? "Only when needed" : "Only for \(PlainText.lowerFirst(medicine.onlyIf))"
        return MedicineRow(medicine: medicine, title: MedicineText.everydayName(medicine),
                           subtitle: subtitle, trailing: state,
                           tone: status.canTakeNow ? .good : .caution, symbol: "timer",
                           swipeTitle: status.canTakeNow ? "Took one" : "")
    }

    // the first line of a verdict short enough for a list row
    private func shortVerdict(_ medicine: MedicineInstruction, verdict: MedicineVerdict) -> String {
        switch verdict.kind {
        case .dontTake:
            if let start = medicine.startDay {
                if start == day { return medicine.reason.isEmpty ? "Stop today" : "Stop today · \(medicine.reason)" }
                return "Stopped since \(DayMath.shortDate(forDay: start, from: surgeryDate))"
            }
            return "Don\u{2019}t take"
        case .okToTake:
            return medicine.onlyIf.isEmpty ? "OK to take" : "If \(PlainText.lowerFirst(medicine.onlyIf))"
        case .startsLater:
            let how = medicine.action == .take ? "Every day" : "Only when needed"
            return "\(how) from \(DayMath.shortDate(forDay: medicine.startDay ?? day, from: surgeryDate))"
        case .finished, .stopEnded:
            guard let end = medicine.endDay else { return verdict.headline }
            return "\(verdict.headline) · \(DayMath.shortDate(forDay: end, from: surgeryDate))"
        default:
            return verdict.headline
        }
    }

    // dose a take swipe logs missed or due first then next
    private func nextOpenSlot(for medicine: MedicineInstruction) -> DoseSlot? {
        let open = todaySlots.filter { $0.medicine.persistentModelID == medicine.persistentModelID && $0.log == nil }
        return open.first { $0.state == .missed || $0.state == .due } ?? open.first
    }
}

// MARK: - What a verdict looks like (shared by every medicine screen)

extension VerdictKind {
    var tone: Tone {
        switch self {
        case .dontTake: return .stop
        case .stopSoon: return .caution
        case .stopEnded, .finished, .startsLater: return .neutral
        case .okToTake: return .good
        case .take, .asNeeded: return .info
        }
    }

    var symbol: String {
        switch self {
        case .dontTake: return "nosign"
        case .stopSoon: return "calendar.badge.exclamationmark"
        case .stopEnded: return "arrow.uturn.backward.circle"
        case .okToTake: return "checkmark.circle.fill"
        case .take: return "pills.fill"
        case .asNeeded: return "timer"
        case .startsLater: return "calendar"
        case .finished: return "checkmark.seal"
        }
    }
}

// MARK: - One-line trailing text (Simple look)

extension MedicineRow {
    // "Next 2:00 PM" in one line
    var trailingLine: String {
        [trailingCaption, trailing].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
