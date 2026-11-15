//
//  MedicineDetailViewModel.swift
//  Remedy
//
//  one medicine for both looks: the classic page rows and the simple answer card
//

import Foundation
import SwiftData

// MARK: - Display data

// "8:00 AM · Taken"
struct DetailDoseRow: Identifiable {
    let slot: DoseSlot
    let timeText: String
    let stateText: String

    var id: DoseSlot.ID { slot.id }
    var state: DoseSlotState { slot.state }
    var spokenLabel: String { "\(timeText), \(stateText)" }
    let spokenHint = "Double-tap to mark as taken or not taken."
}

// one dose chip in the verdict card, "8 AM · taken 8:03"
struct DoseChip: Identifiable {
    let row: DetailDoseRow
    let text: String
    var id: DoseSlot.ID { row.id }
    var isTaken: Bool { row.state == .taken }
}

// the quote sheet: the exact words, which paper, who and when
struct SourceQuoteData {
    let quote: String
    let rows: [InfoRow]
    // the whole page with hidden parts still hidden, "" when we have none
    let pageText: String
}

// a row on the classic detail or the dose log
struct MedicineDetailLine: Identifiable {
    // what tapping a row opens
    enum Target { case none, disagree, visit(Appointment), lookWrong, doseLog, restart, related(MedicineInstruction) }

    let id: String
    let symbol: String
    let tone: Tone
    let title: String
    var subtitle: String = ""
    var subtitleTone: Tone = .neutral
    var target: Target = .none
    // a dose that can be logged from the row
    var dose: DoseSlot? = nil

    var opens: Bool { if case .none = target { return false } else { return true } }
}

// one card on the classic medicine page
struct MedicineDetailCard {
    let style: MedicineCardStyle
    let eyebrow: String
    let symbol: String
    let title: String
    let text: String
    // "I Took One" when it can be taken now, "" for none
    var button: String = ""
}

// the card's colour on the detail
enum MedicineCardStyle { case good, stop, caution }

// MARK: - ViewModel

// everything the medicine pages show about one medicine, both looks
struct MedicineDetailViewModel {

    let medicine: MedicineInstruction
    let now: Date
    let day: Int

    private let verdict: MedicineVerdict
    private let todaySlots: [DoseSlot]
    private let disagrees: Bool

    init(medicine: MedicineInstruction, now: Date) {
        self.medicine = medicine
        self.now = now
        let plan = medicine.plan
        let today = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
        self.day = today
        self.verdict = MedicineMatcher.verdict(for: medicine, today: today, surgeryDate: plan?.surgeryDate ?? now)
        self.todaySlots = (plan.map { DoseSchedule.slotsWithCheck(onDay: today, plan: $0, now: now) } ?? [])
            .filter { $0.medicine.persistentModelID == medicine.persistentModelID }
        self.disagrees = plan.map { PaperCheckReport.of($0).openDisagreements.contains(medicine.persistentModelID) } ?? false
    }

    private var surgeryDate: Date { medicine.plan?.surgeryDate ?? now }
    var kind: VerdictKind { verdict.kind }
    private var isStop: Bool { kind == .dontTake || kind == .stopSoon }

    // "Sun, Oct 25"
    private func dayDate(_ day: Int) -> String {
        DayMath.shortDate(forDay: day, from: surgeryDate)
    }

    // MARK: - Section titles

    let todayTitle = "Today"

    // MARK: - Header

    // "Acetaminophen 500 mg"
    var title: String { MedicineText.fullName(medicine) }

    // "Also called Tylenol" / "A group on your papers" / ""
    var subtitle: String {
        if medicine.isGroup { return "A group on your papers" }
        let own = medicine.name.lowercased()
        let others = medicine.alsoKnownAs.map { $0.lowercased() }.filter { $0 != own && !own.contains($0) }
        if others.isEmpty { return "" }
        return "Also called \(PlainText.list(others.map { $0.capitalized }))"
    }

    // MARK: - Top

    // the big name, the brand people know when there is one: "Eliquis"
    var headerName: String {
        if medicine.isGroup { return medicine.name }
        let own = medicine.name.lowercased()
        let brand = medicine.alsoKnownAs.first { $0.lowercased() != own && !own.contains($0.lowercased()) }
        return brand.map { $0.capitalized } ?? medicine.name
    }

    // the paper's name and strength under it: "apixaban · 2.5 mg"
    var paperNameLine: String {
        if medicine.isGroup { return subtitle }
        let paperName = headerName == medicine.name ? "" : medicine.name.lowercased()
        return [paperName, medicine.strength].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    // MARK: - Verdict card (simple look)

    // the card's colour: take and as needed in accent, paused in caution, the rest plain
    var verdictCardTone: Tone {
        switch verdict.kind {
        case .take, .asNeeded: return .good
        case .dontTake, .stopSoon: return .caution
        default: return .neutral
        }
    }

    // the small word over the answer, "OK FROM 6:40 PM", "PAUSED", "" for an every-day medicine
    var verdictEyebrow: String {
        switch verdict.kind {
        case .asNeeded:
            let status = asNeededStatus
            if status.reachedMax { return "No more today" }
            if let next = status.nextAllowed { return "OK from \(DayMath.timeText(of: next))" }
            return "OK now"
        case .dontTake, .stopSoon: return "Paused"
        case .okToTake: return "Allowed"
        default: return ""
        }
    }

    var verdictEyebrowSymbol: String {
        switch verdict.kind {
        case .asNeeded: return asNeededStatus.canTakeNow ? "checkmark.circle" : "clock"
        case .dontTake, .stopSoon: return "pause.circle"
        case .okToTake: return "checkmark.circle"
        default: return ""
        }
    }

    // the answer in one line: "Take 1 tablet, twice a day", "1 tablet if you need it"
    var verdictTitle: String {
        switch verdict.kind {
        case .take:
            let count = medicine.timesOfDay.count
            guard count > 0 else { return verdict.sentence }
            let often = MedicinesViewModel.howOften(count)
            return medicine.amount.isEmpty ? "Take it \(often)" : "Take \(medicine.amount), \(often)"
        case .asNeeded:
            let what = medicine.amount.isEmpty ? "Take it" : medicine.amount
            return medicine.onlyIf.isEmpty ? "\(what) if you need it" : "\(what) if \(PlainText.lowerFirst(medicine.onlyIf))"
        case .stopSoon:
            return "Last dose \(dayWord((medicine.startDay ?? day) - 1))"
        case .dontTake:
            return "Don\u{2019}t take it for now"
        case .okToTake:
            return "Your papers say it\u{2019}s fine"
        default:
            return verdict.headline
        }
    }

    // calendar words, never day counters: "today", "Saturday", "Dec 3"
    private func dayWord(_ planDay: Int) -> String {
        SimpleWording.dayWord(for: DayMath.date(forDay: planDay, from: surgeryDate), now: now)
    }

    // when a paused medicine starts again
    private var restartText: String {
        if let end = medicine.endDay { return "Restart \(dayWord(end + 1))" }
        return "Restart when your surgeon says it\u{2019}s OK"
    }

    // the line under it: last dose and how many are left, or what the verdict means
    var verdictDetail: String {
        switch verdict.kind {
        case .take: return medicine.foodNote
        case .asNeeded:
            let status = asNeededStatus
            var parts: [String] = []
            if let last = status.lastTaken, last >= DayMath.calendar.startOfDay(for: now) {
                parts.append("Last one at \(DayMath.timeText(of: last))")
            }
            if let max = medicine.maxPerDay { parts.append("\(Swift.max(0, max - status.takenToday)) left today") }
            return parts.joined(separator: " \u{00B7} ")
        case .stopSoon: return "Then pause it. \(restartText)."
        case .dontTake: return "\(restartText)."
        default: return verdict.sentence
        }
    }

    // today's doses as chips: "8 AM · taken 8:03", "8 PM · next"
    var doseChips: [DoseChip] {
        let next = todaySlots.first { $0.state == .due || $0.state == .upcoming }
        return todayDoses.map { row in
            let time = DayMath.shortTimeText(row.slot.minute)
            let state: String
            switch row.state {
            case .taken:
                if row.slot.givenInHospital { state = "given in hospital" }
                else { state = "taken \(DayMath.timeText(of: row.slot.log?.loggedAt ?? row.slot.scheduledFor).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: ""))" }
            case .skipped: state = "skipped"
            case .missed: state = "missed"
            case .due: state = "due now"
            case .upcoming: state = row.slot.id == next?.id ? "next" : "later"
            }
            return DoseChip(row: row, text: "\(time) \u{00B7} \(state)")
        }
    }

    // the whole card for read to me and VoiceOver
    var verdictSpokenCard: String {
        ([verdictEyebrow, verdictTitle, verdictDetail] + doseChips.map(\.text)).filter { !$0.isEmpty }.joined(separator: ". ")
    }

    // MARK: - As needed actions

    let earlierDoseTitle = "Log an Earlier Dose"
    let earlierDoseFooter = "Only times from midnight until now. The \u{201C}Can I take it now?\u{201D} card counts from this time."
    let earlierDoseSave = "Save"
    let earlierDoseQuestion = "When did you take it?"

    // an earlier dose can be any time today up to now
    var earlierDoseRange: ClosedRange<Date> { DayMath.calendar.startOfDay(for: now)...now }

    // saves a dose the patient took earlier today
    func logEarlier(at time: Date, in context: ModelContext) {
        let clamped = min(max(time, earlierDoseRange.lowerBound), now)
        DoseActions.logAsNeeded(medicine, now: clamped, in: context)
    }

    // MARK: - "Log a dose?" check (only when needed)

    var logConfirmationTitle: String { "Log a dose of \(MedicineText.fullName(medicine)) now?" }

    // reminds them of the papers' limits before they log
    var logConfirmationMessage: String {
        var parts: [String] = []
        if let hours = medicine.minHoursBetween { parts.append("Wait at least \(hours) hours between doses.") }
        if let max = medicine.maxPerDay { parts.append("No more than \(max) a day.") }
        return parts.isEmpty ? "From your papers." : "Your papers say: " + parts.joined(separator: " ")
    }
    let logConfirmButton = "Log dose"

    // MARK: - Source quote sheet

    private var paperRecord: Paper? {
        medicine.plan?.papers.first { $0.id == medicine.paperID }
    }

    private var page: SourceDocument? {
        medicine.plan?.documents.first {
            $0.paperID == medicine.paperID && (medicine.quotePage == nil || $0.pageNumber == medicine.quotePage)
        }
    }

    let quoteSheetTitle = "Where this came from"
    let simplePaperSays = "Your paper says"

    // a report about this medicine with personal details hidden
    var mistakeReport: MistakeReport {
        let facts = [("Action", medicine.action.rawValue), ("Amount", medicine.amount), ("Strength", medicine.strength),
                     ("Only if", medicine.onlyIf), ("Reason", medicine.reason), ("Exception", medicine.exception)]
            .filter { !$0.1.isEmpty }.map { "\($0.0): \($0.1)" }
        return MistakeReport(item: ([title] + facts).joined(separator: "\n"), quote: medicine.quote,
                             pageText: page?.redactedText ?? "", reader: "Not saved with the plan")
    }

    // the exact words, the paper, the doctor and hospital, the printed date
    var sourceQuote: SourceQuoteData {
        var rows: [InfoRow] = []
        let paper = paperRecord
        rows.append(InfoRow(id: "paper", label: "Paper", value: paperKindText(paper)))
        if let paper {
            let from = [doctorName(paper) ?? "", paper.hospitalName ?? medicine.plan?.hospitalName ?? ""].filter { !$0.isEmpty }
            if !from.isEmpty { rows.append(InfoRow(id: "from", label: "From", value: from.joined(separator: " \u{00B7} "))) }
            rows.append(InfoRow(id: "printed", label: "Printed", value: paper.printedDate.map { DayMath.longDate($0) } ?? "No date on the paper"))
        }
        if let number = medicine.quotePage { rows.append(InfoRow(id: "page", label: "Page", value: "\(number)")) }
        return SourceQuoteData(quote: medicine.quote, rows: rows, pageText: page?.redactedText ?? "")
    }

    private func paperKindText(_ paper: Paper?) -> String {
        guard let paper else { return medicine.paper == .afterSurgery ? "After-surgery papers" : "Before-surgery papers" }
        switch paper.source {
        case .surgeryTeam: return paper.kind == .afterSurgery ? "Discharge instructions" : "Before-surgery instructions"
        case .hospitalRecord: return "Hospital record"
        case .primaryCare: return "Family doctor\u{2019}s paper"
        case .specialist: return "Specialist\u{2019}s paper"
        case .other: return paper.otherKindText.isEmpty ? "Another paper" : paper.otherKindText
        }
    }

    private func doctorName(_ paper: Paper) -> String? {
        guard let name = paper.doctorName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        let lower = name.lowercased()
        return lower.hasPrefix("dr") ? name : "Dr. \(name)"
    }

    // MARK: - Today's doses (simple look)

    var todayDoses: [DetailDoseRow] {
        todaySlots.map { slot in
            let stateText: String
            switch slot.state {
            case .taken: stateText = "Taken at \(DayMath.timeText(of: slot.log?.loggedAt ?? slot.scheduledFor))"
            case .skipped: stateText = "Skipped"
            case .missed: stateText = "Missed"
            case .due: stateText = "Due now"
            case .upcoming: stateText = "Later"
            }
            return DetailDoseRow(slot: slot, timeText: DayMath.timeText(slot.minute), stateText: stateText)
        }
    }

    // for the little progress bar over today's doses
    var todayTakenCount: Int { todaySlots.filter { $0.state == .taken }.count }

    // MARK: - Only when needed

    var showsAsNeeded: Bool {
        medicine.action == .takeAsNeeded && DoseSchedule.isActive(medicine, on: day)
    }

    private var asNeededStatus: AsNeededStatus {
        DoseSchedule.asNeededStatus(for: medicine, now: now)
    }

    var canLogAsNeeded: Bool { asNeededStatus.canTakeNow }

    // MARK: - Actions

    // ticks a dose on or off
    func toggle(_ row: DetailDoseRow, in context: ModelContext) {
        if let log = row.slot.log {
            DoseActions.remove(log, in: context)
        } else {
            DoseActions.log(medicine, scheduledFor: row.slot.scheduledFor, as: .taken, now: now, in: context)
        }
    }

    // i took one
    func logAsNeeded(in context: ModelContext) {
        guard canLogAsNeeded else { return }
        DoseActions.logAsNeeded(medicine, now: now, in: context)
    }

    // a nil answer removes the log so the dose is open again
    func setAnswer(_ status: DoseStatus?, for slot: DoseSlot, in context: ModelContext) {
        if let log = slot.log { DoseActions.remove(log, in: context) }
        if let status { DoseActions.log(medicine, scheduledFor: slot.scheduledFor, as: status, now: now, in: context) }
    }

    func change(_ slot: DoseSlot, to status: DoseStatus, takenAt: Date, in context: ModelContext) {
        DoseActions.change(medicine, scheduledFor: slot.scheduledFor, to: status, takenAt: takenAt, in: context)
    }

    // MARK: - Classic page words

    let editButton = "Edit"
    let lookWrongTitle = "Something Looks Wrong"
    let lookWrongMessage = "If the bottle says something different, follow the bottle and call the pharmacy."
    let showWordsButton = "Show the Paper\u{2019}s Words"
    let fixButton = "Fix It Myself"
    let callPharmacyButton = "Call Hospital Pharmacy"
    let takenHeader = "Taken"
    let tookOneButton = "I Took One"

    // the classic page's big name
    var pageTitle: String { MedicineText.fullName(everyday: medicine) }

    // "Only when needed · for severe pain", "Every day · helps prevent blood clots", "Also called: Aleve, Naprosyn"
    var pageSubtitle: String {
        let reason = medicine.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = reason.isEmpty ? "" : PlainText.lowerFirst(reason)
        switch kind {
        case .finished:
            return "Finished \(dayDate(medicine.endDay ?? day))"
        case .dontTake, .stopSoon, .stopEnded:
            // "Also called: Aleve, Naprosyn", every other name it goes by
            guard !medicine.isGroup else { return "" }
            let others = names(medicine).dropFirst().map { $0.capitalized }
            return others.isEmpty ? "" : "Also called: \(others.joined(separator: ", "))"
        case .asNeeded:
            return ["Only when needed", why].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        case .okToTake:
            return "Every day \u{00B7} keep taking your usual dose"
        default:
            return ["Every day", why].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        }
    }

    private func names(_ medicine: MedicineInstruction) -> [String] {
        MedicineIdentity.names(medicine.name, alsoKnownAs: medicine.alsoKnownAs)
    }

    // only paper lines can be fixed by hand, a stopped one restarts through its own screen
    var showsEdit: Bool { medicine.plan != nil && !isStop }

    // the answer card, only for as needed and stopped medicines
    var card: MedicineDetailCard? {
        switch kind {
        case .asNeeded:
            let status = asNeededStatus
            let wait = medicine.minHoursBetween.map { "After you take one, wait \($0) hours." } ?? ""
            let last = status.lastTaken.map { "Last one at \(DayMath.timeText(of: $0))." } ?? ""
            let text = [last, wait].filter { !$0.isEmpty }.joined(separator: " ")
            if status.reachedMax {
                return MedicineDetailCard(style: .caution, eyebrow: "Can I take it now?", symbol: "clock",
                                  title: "No more today.", text: text)
            }
            if let next = status.nextAllowed {
                return MedicineDetailCard(style: .caution, eyebrow: "Can I take it now?", symbol: "clock",
                                  title: "Not yet. Next one at \(DayMath.timeText(of: next)).", text: text)
            }
            return MedicineDetailCard(style: .good, eyebrow: "Can I take it now?", symbol: "checkmark.circle",
                              title: "Yes, \(PlainText.lowerFirst(MedicinesViewModel.takeNowText(medicine.amount))).",
                              text: text, button: tookOneButton)
        case .dontTake:
            let until = medicine.endDay.map { "Not until \(dayDate($0 + 1))." } ?? "Not until your surgeon says it\u{2019}s OK."
            let why = medicine.exception.isEmpty ? "" : sentence(medicine.exception)
            return MedicineDetailCard(style: .stop, eyebrow: "Stopped for now", symbol: "nosign", title: "Don\u{2019}t take it.",
                              text: [until, why].filter { !$0.isEmpty }.joined(separator: " "))
        case .stopSoon:
            let last = (medicine.startDay ?? day) - 1
            return MedicineDetailCard(style: .stop, eyebrow: "Stopping soon", symbol: "nosign",
                              title: "Last dose \(dayDate(last)).",
                              text: "Then don\u{2019}t take it until your surgeon says it\u{2019}s OK.")
        default:
            return nil
        }
    }

    private func sentence(_ text: String) -> String {
        let clean = PlainText.upperFirst(text.trimmingCharacters(in: .whitespacesAndNewlines))
        return clean.hasSuffix(".") ? clean : clean + "."
    }

    // one dose as a row, the log lets a tap change a taken or skipped dose too
    private func doseLine(_ slot: DoseSlot, id: String, title: String, editable: Bool) -> MedicineDetailLine {
        if slot.givenInHospital {
            return MedicineDetailLine(id: id, symbol: "bed.double", tone: .neutral, title: title, subtitle: "In hospital")
        }
        let changed = slot.log?.changedByYou == true
        switch slot.state {
        case .taken:
            var at = slot.log.map { "Took it at \(DayMath.timeText(of: $0.loggedAt))" } ?? "Took it"
            if changed { at += " \u{00B7} changed by you" }
            return MedicineDetailLine(id: id, symbol: "checkmark.circle", tone: .good, title: title, subtitle: at,
                                      dose: editable ? slot : nil)
        case .skipped:
            return MedicineDetailLine(id: id, symbol: "exclamationmark.triangle", tone: .caution, title: title,
                                      subtitle: editable && changed ? "Skipped \u{00B7} changed by you" : "Skipped",
                                      subtitleTone: .caution, dose: editable ? slot : nil)
        case .missed:
            return MedicineDetailLine(id: id, symbol: "exclamationmark.triangle", tone: .caution, title: title,
                                      subtitle: "Missed", subtitleTone: .caution, dose: slot)
        case .due:
            return MedicineDetailLine(id: id, symbol: "clock", tone: .info, title: title, subtitle: "Due now", dose: slot)
        case .upcoming:
            return MedicineDetailLine(id: id, symbol: "clock", tone: .neutral, title: title, subtitle: "Later today", dose: slot)
        }
    }

    // today's doses on the classic page
    var todayRows: [MedicineDetailLine] {
        todaySlots.map { slot in
            let time = DayMath.timeText(of: slot.scheduledFor)
            let title = medicine.amount.isEmpty ? time : "\(time) \u{00B7} \(medicine.amount)"
            return doseLine(slot, id: "slot-\(slot.minute)", title: title, editable: false)
        }
    }

    // MARK: - Facts

    var factRows: [MedicineDetailLine] {
        var rows: [MedicineDetailLine] = []
        if disagrees {
            rows.append(MedicineDetailLine(id: "disagree", symbol: "exclamationmark.triangle", tone: .stop,
                                   title: "Your papers disagree", subtitle: "Tap to see both", subtitleTone: .stop,
                                   target: .disagree))
        }
        if !medicine.onlyIf.isEmpty {
            rows.append(MedicineDetailLine(id: "onlyIf", symbol: "info.circle", tone: .info, title: "Only if \(PlainText.lowerFirst(medicine.onlyIf))"))
        }
        if !medicine.foodNote.isEmpty {
            rows.append(MedicineDetailLine(id: "food", symbol: "fork.knife", tone: .info, title: PlainText.upperFirst(medicine.foodNote)))
        }
        if isStop {
            if let start = medicine.startDay {
                rows.append(MedicineDetailLine(id: "last", symbol: "clock", tone: .neutral, title: "Last dose", subtitle: dayDate(start - 1)))
            }
            if let visit = nextVisit {
                rows.append(MedicineDetailLine(id: "ask", symbol: "calendar", tone: .info, title: "Ask at",
                                       subtitle: "\(visit.title), \(DayMath.shortDate(visit.date))", target: .visit(visit)))
            }
            if medicine.isGroup, !medicine.alsoKnownAs.isEmpty {
                rows.append(MedicineDetailLine(id: "also", symbol: "nosign", tone: .stop, title: "Also don\u{2019}t take",
                                       subtitle: PlainText.list(medicine.alsoKnownAs.map { $0.capitalized })))
            }
        } else {
            if medicine.isGroup, !medicine.alsoKnownAs.isEmpty {
                rows.append(MedicineDetailLine(id: "covers", symbol: "list.bullet", tone: .info, title: "Includes",
                                       subtitle: PlainText.list(medicine.alsoKnownAs.map { $0.capitalized })))
            }
            if !medicine.exception.isEmpty {
                rows.append(MedicineDetailLine(id: "exception", symbol: "info.circle", tone: .info, title: sentence(medicine.exception)))
            }
            if let end = medicine.endDay, kind != .finished, medicine.plan?.surgeryDate != nil {
                rows.append(MedicineDetailLine(id: "until", symbol: "calendar", tone: .info, title: "Until \(dayDate(end))",
                                       subtitle: end >= 0 ? "\(PlainText.count(end, "day")) after surgery" : "Before surgery"))
            }
        }
        if let note = medicine.restartNote, !note.isEmpty {
            rows.append(MedicineDetailLine(id: "restart-note", symbol: "checkmark.circle", tone: .good, title: note))
        }
        if let changed = medicine.changedByYouAt {
            rows.append(MedicineDetailLine(id: "changed", symbol: "pencil", tone: .neutral, title: "Changed by you",
                                   subtitle: DayMath.shortDate(changed)))
        }
        rows.append(MedicineDetailLine(id: "wrong", symbol: "flag", tone: .info, title: lookWrongTitle,
                               subtitle: "Fix it or tell your care team", target: .lookWrong))
        return rows
    }

    private var nextVisit: Appointment? {
        let start = DayMath.calendar.startOfDay(for: now)
        return (medicine.plan?.appointments ?? []).filter { $0.date >= start }.min { $0.date < $1.date }
    }

    // MARK: - The paper's words

    // a medicine the patient added has no line from the papers
    var hasPaperQuote: Bool { !medicine.quote.isEmpty }
    var quoteHeader: String { medicine.quotePage.map { "From your paper, page \($0)" } ?? "From your paper" }
    var quoteText: String { "\u{201C}\(medicine.quote)\u{201D}" }
    var quotePlain: String { PaperAbbreviations.explain(medicine.quote) }

    // MARK: - Below the quote

    var restartRow: MedicineDetailLine? {
        kind == .dontTake ? MedicineDetailLine(id: "restart", symbol: "checkmark.circle", tone: .info,
                                       title: "My Surgeon Said I Can Restart", target: .restart) : nil
    }

    var doseLogRow: MedicineDetailLine? {
        guard medicine.action == .take, medicine.plan?.surgeryDate != nil else { return nil }
        return MedicineDetailLine(id: "log", symbol: "list.bullet", tone: .info, title: doseLogTitle,
                          subtitle: "Every dose since surgery", target: .doseLog)
    }

    // the same medicine on another paper, kept from before the redesign
    let relatedHeader = "Also on your papers"
    let relatedNote = "Different papers can say different things. Tap one to see its words. Ask your care team if they don\u{2019}t fit together."
    var relatedLines: [MedicineDetailLine] {
        guard let plan = medicine.plan else { return [] }
        let mine = Set(names(medicine))
        return plan.medicines
            .filter { $0.isConfirmed && $0.persistentModelID != medicine.persistentModelID && !mine.isDisjoint(with: names($0)) }
            .map { other in
                MedicineDetailLine(id: "related-\(other.persistentModelID.hashValue)", symbol: "doc.text", tone: .info,
                           title: paperTitle(other, plan: plan), subtitle: relatedLine(other),
                           target: .related(other))
            }
    }

    // "Before surgery paper", "Heart doctor note"
    private func paperTitle(_ other: MedicineInstruction, plan: CarePlan) -> String {
        if let id = other.paperID, let paper = plan.papers.first(where: { $0.id == id }), paper.source == .specialist {
            let field: String
            switch paper.field {
            case .heart?: field = "Heart doctor"
            case .kidney?: field = "Kidney doctor"
            case .blood?: field = "Blood doctor"
            case .diabetes?: field = "Diabetes doctor"
            case .lungs?: field = "Lung doctor"
            default: field = "Another doctor"
            }
            return "\(field) note"
        }
        return other.paper == .beforeSurgery ? "Before surgery paper" : "After surgery paper"
    }

    // "If you need something for pain, until Sun, Nov 8", "Up to 3,000 mg a day"
    private func relatedLine(_ other: MedicineInstruction) -> String {
        var first = ""
        if !other.onlyIf.isEmpty { first = "If \(PlainText.lowerFirst(other.onlyIf))" }
        else if other.action == .stop { first = "Stop it" }
        else { first = MedicineText.howText(other) }
        if let end = other.endDay { first += first.isEmpty ? "Until \(dayDate(end))" : ", until \(dayDate(end))" }
        return first
    }

    // 32, a dose taken without tapping
    let logEarlierText = "Took one and didn\u{2019}t tap I Took One"

    var takenRows: [MedicineDetailLine] {
        let taken = medicine.doseLogs.filter { $0.status == .taken }.sorted { $0.loggedAt > $1.loggedAt }
        let byDay = Dictionary(grouping: taken) { DayMath.calendar.startOfDay(for: $0.loggedAt) }
        return byDay.keys.sorted(by: >).prefix(5).map { start in
            let times = (byDay[start] ?? []).map { DayMath.timeText(of: $0.loggedAt) }.joined(separator: " \u{00B7} ")
            return MedicineDetailLine(id: "taken-\(start.timeIntervalSince1970)", symbol: "clock", tone: .neutral,
                              title: PlainText.upperFirst(SimpleWording.dayWord(for: start, now: now)), subtitle: times)
        }
    }

    // MARK: - Dose log (34), every day from the first dose to today, newest first

    let doseLogTitle = "Dose Log"
    let doseLogFooter = "Tap a dose to change its answer or time. Changes are kept and marked."
    // 94 words
    let changeTimeHeader = "Time you took it"
    let changedFooter = "Changed doses are marked \u{201C}changed by you\u{201D} in the log."
    let clearAskTitle = "Clear this answer?"
    let logTookButton = "I Took It"
    let logSkipButton = "I Skipped It"
    let logClearButton = "Clear the Answer"

    // "Tue, Nov 10 · 8:00 PM"
    func changeTitle(_ slot: DoseSlot) -> String {
        "\(DayMath.shortDate(slot.scheduledFor)) \u{00B7} \(DayMath.timeText(of: slot.scheduledFor))"
    }

    // the time already taken, else the planned time
    func startTime(_ slot: DoseSlot) -> Date {
        slot.log.flatMap { $0.status == .taken ? $0.loggedAt : nil } ?? slot.scheduledFor
    }

    // one day of the dose log
    struct LogDay: Identifiable {
        let id: Int
        let title: String
        let rows: [MedicineDetailLine]
    }

    var doseLogDays: [LogDay] {
        guard let plan = medicine.plan, plan.surgeryDate != nil else { return [] }
        let skipped = PaperCheckReport.of(plan).skipped
        let first = max(medicine.startDay ?? day, day - 60)
        guard first <= day else { return [] }
        return (first...day).reversed().compactMap { planDay in
            let daySlots = DoseSchedule.slots(onDay: planDay, plan: plan, now: now, skipped: skipped)
                .filter { $0.medicine.persistentModelID == medicine.persistentModelID }
            guard !daySlots.isEmpty else { return nil }
            let date = dayDate(planDay)
            return LogDay(id: planDay, title: planDay == day ? "Today \u{00B7} \(date)" : date,
                          rows: daySlots.map { slot in
                              doseLine(slot, id: "log-\(slot.scheduledFor.timeIntervalSince1970)",
                                       title: DayMath.timeText(of: slot.scheduledFor), editable: true)
                          })
        }
    }

    var pharmacyCall: URL? {
        medicine.plan?.contacts.first { $0.role == .pharmacy && !$0.phone.isEmpty }.flatMap { DayMath.phoneURL($0.phone) }
    }
}
