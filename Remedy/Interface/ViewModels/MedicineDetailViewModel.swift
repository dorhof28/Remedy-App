//
//  MedicineDetailViewModel.swift
//  Remedy
//
//  one medicine for both looks
//

import Foundation
import SwiftData

// MARK: - Display data

// "How much · 2 tablets"
struct DetailFact: Identifiable {
    let id: String              // "amount"
    let symbol: String
    let label: String           // "How much"
    let value: String           // "2 tablets"
}

// "8:00 AM · Taken"
struct DetailDoseRow: Identifiable {
    let slot: DoseSlot
    let timeText: String
    let stateText: String
    let tone: Tone

    var id: DoseSlot.ID { slot.id }
    var state: DoseSlotState { slot.state }
    var spokenLabel: String { "\(timeText), \(stateText)" }
    let spokenHint = "Double-tap to mark as taken or not taken."
}

// "Your papers also say Aspirin 81 mg · Take every day"
struct RelatedRow: Identifiable {
    let medicine: MedicineInstruction
    let title: String           // "Aspirin 81 mg"
    let subtitle: String        // "After-surgery papers · Take every day"
    let tone: Tone
    let symbol: String

    var id: PersistentIdentifier { medicine.persistentModelID }
}

// a small box at the top of an every-day medicine
struct StatBox: Identifiable {
    let id: String
    let title: String           // "Today"
    let value: String           // "1 of 2"
    let caption: String         // "Next at 8:00 PM"
    let progress: Double?       // 0...1, nil = no bar
}

// the countdown ring for an only-when-needed medicine
struct DoseTimer {
    let label: String           // "Next dose in"
    let value: String           // "1 h 45 min" / "OK now"
    let caption: String         // "OK at 3:20 PM"
    let progress: Double        // how much of the wait has passed (0...1)
    let isAllowedNow: Bool
}

// the coloured box for stop / OK / not started / finished medicines
struct StatusBox {
    let tone: Tone
    let eyebrow: String         // "DON'T TAKE RIGHT NOW"
    let title: String           // "Stopped since Sun, Oct 25. Don't take it until..."
}

// MARK: - ViewModel

struct MedicineDetailViewModel {

    let medicine: MedicineInstruction
    let now: Date
    let day: Int

    private let verdict: MedicineVerdict
    private let todaySlots: [DoseSlot]

    init(medicine: MedicineInstruction, now: Date) {
        self.medicine = medicine
        self.now = now
        let plan = medicine.plan
        let today = plan.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0
        self.day = today
        self.verdict = MedicineMatcher.verdict(for: medicine, today: today, surgeryDate: plan?.surgeryDate ?? now)
        self.todaySlots = (plan.map { DoseSchedule.slots(onDay: today, plan: $0, now: now) } ?? [])
            .filter { $0.medicine.persistentModelID == medicine.persistentModelID }
    }

    private var surgeryDate: Date { medicine.plan?.surgeryDate ?? now }

    // MARK: - Section titles

    let todayTitle = "Today"
    let asNeededTitle = "Only when needed"
    let aboutTitle = "About"
    let includesTitle = "Includes"
    let smallPrintTitle = "The small print"
    let relatedTitle = "Also on your papers"
    let relatedFooter = "The same medicine can have different instructions before and after surgery."

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

    var pillShape: String { medicine.pillShape }
    var pillColor: String { medicine.pillColor }

    var verdictHeadline: String { verdict.headline }
    var verdictSentence: String { verdict.sentence }
    var verdictTone: Tone { verdict.kind.tone }
    var verdictSymbol: String { verdict.kind.symbol }
    var verdictSpoken: String { "\(verdict.headline). \(verdict.sentence)" }

    // MARK: - Top card (big icon at the top)

    var topSymbol: String { verdict.kind.symbol }
    var topTone: Tone { verdict.kind.tone }

    // MARK: - The block under the top card (depends on the kind of medicine)

    // every-day medicine in effect "Today 1 of 2" + "Course day 3 of 14"
    var showsStatBoxes: Bool { verdict.kind == .take }

    var statBoxes: [StatBox] {
        var boxes: [StatBox] = []
        let taken = todaySlots.filter { $0.state == .taken }.count
        let next = todaySlots.first { $0.state == .due || $0.state == .upcoming }
        boxes.append(StatBox(
            id: "today",
            title: "Today",
            value: "\(taken) of \(todaySlots.count)",
            caption: next.map { "Next at \(DayMath.timeText($0.minute))" } ?? "All done today",
            progress: todaySlots.isEmpty ? nil : Double(taken) / Double(todaySlots.count)
        ))
        if let start = medicine.startDay, let end = medicine.endDay, end >= start {
            let total = end - start + 1
            let done = min(max(day - start + 1, 0), total)
            boxes.append(StatBox(
                id: "course",
                title: "Course",
                value: "Day \(done) of \(total)",
                caption: "Last day \(DayMath.shortDate(forDay: end, from: surgeryDate))",
                progress: Double(done) / Double(total)
            ))
        }
        return boxes
    }

    // only-when-needed medicine in effect the countdown ring
    var showsTimer: Bool { showsAsNeeded }

    var timer: DoseTimer {
        let status = asNeededStatus
        if status.reachedMax {
            return DoseTimer(label: "Today", value: "No more today",
                             caption: "\(status.takenToday) of \(medicine.maxPerDay ?? status.takenToday) taken",
                             progress: 1, isAllowedNow: false)
        }
        if let next = status.nextAllowed, let last = status.lastTaken {
            let wait = next.timeIntervalSince(last)
            let passed = now.timeIntervalSince(last)
            let minutesLeft = max(0, Int(next.timeIntervalSince(now) / 60))
            return DoseTimer(label: "Next dose in", value: DayMath.duration(minutes: minutesLeft),
                             caption: "OK at \(DayMath.timeText(of: next))",
                             progress: wait > 0 ? passed / wait : 1, isAllowedNow: false)
        }
        let caption = medicine.onlyIf.isEmpty ? "If you need it" : "Only for \(PlainText.lowerFirst(medicine.onlyIf))"
        return DoseTimer(label: "Next dose", value: "OK now", caption: caption, progress: 1, isAllowedNow: true)
    }

    // everything else one coloured box that says what it means today
    var showsStatusBox: Bool { !showsStatBoxes && !showsTimer }

    var statusBox: StatusBox {
        let eyebrow: String
        switch verdict.kind {
        case .dontTake: eyebrow = "Don\u{2019}t take right now"
        case .stopSoon: eyebrow = verdict.headline
        case .okToTake: eyebrow = "OK to take"
        default: eyebrow = verdict.headline
        }
        return StatusBox(tone: verdict.kind.tone, eyebrow: eyebrow, title: verdict.sentence)
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

    // MARK: - How to take it

    var howToRows: [InfoRow] {
        facts.map { InfoRow(id: $0.id, label: $0.label, value: $0.value) }
    }
    var showsHowTo: Bool { !howToRows.isEmpty }
    var howToTitle: String { medicine.action == .stop ? "Details" : "How to take it" }
    let paperTitle = "From your papers"

    // MARK: - History (last 10 logged doses)

    var historyRows: [InfoRow] {
        medicine.doseLogs
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(10)
            .map { log in
                let status = log.status == .taken ? "Taken" : "Skipped"
                return InfoRow(id: "\(log.persistentModelID)",
                               label: DayMath.shortDate(log.loggedAt),
                               value: "\(DayMath.timeText(of: log.loggedAt)) · \(status)")
            }
    }
    var showsHistory: Bool { !historyRows.isEmpty }
    let historyTitle = "History"

    // MARK: - Today's doses (every-day medicines)

    var showsTodayDoses: Bool { !todaySlots.isEmpty }

    var todayDoses: [DetailDoseRow] {
        todaySlots.map { slot in
            let stateText: String
            let tone: Tone
            switch slot.state {
            case .taken:
                stateText = "Taken at \(DayMath.timeText(of: slot.log?.loggedAt ?? slot.scheduledFor))"
                tone = .good
            case .skipped: stateText = "Skipped"; tone = .neutral
            case .missed: stateText = "Missed"; tone = .stop
            case .due: stateText = "Due now"; tone = .info
            case .upcoming: stateText = "Later"; tone = .neutral
            }
            return DetailDoseRow(slot: slot, timeText: DayMath.timeText(slot.minute), stateText: stateText, tone: tone)
        }
    }

    // "1 of 2 taken today"
    var todayDosesSummary: String {
        "\(todaySlots.filter { $0.state == .taken }.count) of \(todaySlots.count) taken today"
    }

    // MARK: - Only when needed

    var showsAsNeeded: Bool {
        medicine.action == .takeAsNeeded && DoseSchedule.isActive(medicine, on: day)
    }

    private var asNeededStatus: AsNeededStatus {
        DoseSchedule.asNeededStatus(for: medicine, now: now)
    }

    // "OK to take one now" / "Next one OK at 3:20 PM " / "No more today"
    var asNeededStatusText: String {
        let status = asNeededStatus
        if status.reachedMax { return "No more today. You\u{2019}ve had the most your papers allow." }
        if let next = status.nextAllowed {
            let minutes = max(0, Int(next.timeIntervalSince(now) / 60))
            return "Next one OK at \(DayMath.timeText(of: next)) (in \(DayMath.duration(minutes: minutes)))"
        }
        return "OK to take one now, if you need it"
    }

    var asNeededTone: Tone { asNeededStatus.canTakeNow ? .good : .caution }

    // "1 of 4 taken today · last at 9:20 AM"
    var asNeededDetail: String {
        let status = asNeededStatus
        var text = "\(status.takenToday)"
        if let max = medicine.maxPerDay { text += " of \(max)" }
        text += " taken today"
        if let last = status.lastTaken, last >= DayMath.calendar.startOfDay(for: now) {
            text += " · last at \(DayMath.timeText(of: last))"
        }
        return text
    }

    var canLogAsNeeded: Bool { asNeededStatus.canTakeNow }
    let logButtonTitle = "I took one now"

    // MARK: - Facts

    var facts: [DetailFact] {
        var list: [DetailFact] = []
        if !medicine.amount.isEmpty {
            list.append(DetailFact(id: "amount", symbol: "pills", label: "How much", value: medicine.amount))
        }
        if !medicine.timesOfDay.isEmpty {
            list.append(DetailFact(id: "times", symbol: "clock", label: "When", value: MedicineText.timesText(medicine)))
        }
        if !medicine.foodNote.isEmpty {
            list.append(DetailFact(id: "food", symbol: "fork.knife", label: "Food", value: medicine.foodNote))
        }
        if !medicine.onlyIf.isEmpty {
            list.append(DetailFact(id: "onlyIf", symbol: "questionmark.circle", label: "Only if", value: medicine.onlyIf))
        }
        if let hours = medicine.minHoursBetween {
            list.append(DetailFact(id: "between", symbol: "timer", label: "Wait between", value: "\(hours) hours"))
        }
        if let max = medicine.maxPerDay {
            list.append(DetailFact(id: "max", symbol: "number", label: "Most a day", value: "\(max)"))
        }
        if let start = medicine.startDay {
            list.append(DetailFact(id: "start", symbol: "calendar", label: medicine.action == .stop ? "Stop from" : "From", value: dayText(start)))
        }
        if let end = medicine.endDay {
            list.append(DetailFact(id: "end", symbol: "calendar.badge.checkmark", label: "Until", value: dayText(end)))
        } else if medicine.action == .stop {
            list.append(DetailFact(id: "end", symbol: "calendar.badge.checkmark", label: "Until", value: "Your surgeon says it\u{2019}s OK"))
        }
        if !medicine.reason.isEmpty {
            list.append(DetailFact(id: "reason", symbol: "info.circle", label: "Why", value: medicine.reason))
        }
        return list
    }

    // MARK: - Group members and small print

    // for groups every name it covers so "fish oil" is easy to spot
    var coversText: String {
        guard medicine.isGroup else { return "" }
        return PlainText.list(medicine.alsoKnownAs.map { $0.capitalized })
    }
    var showsCovers: Bool { !coversText.isEmpty }

    // word for word from the papers
    var exceptionText: String { medicine.exception }
    var showsException: Bool { !exceptionText.isEmpty }

    // MARK: - Other instructions for the same medicine

    // instructions that share a name with this one
    var related: [RelatedRow] {
        let names = Set(MedicineMatcher.names(of: medicine))
        let others = (medicine.plan?.medicines ?? []).filter { other in
            other.persistentModelID != medicine.persistentModelID
                && other.isConfirmed
                && !names.isDisjoint(with: MedicineMatcher.names(of: other))
        }
        return others.map { other in
            let otherVerdict = MedicineMatcher.verdict(for: other, today: day, surgeryDate: surgeryDate)
            let paper = other.paper == .beforeSurgery ? "Before-surgery papers" : "After-surgery papers"
            return RelatedRow(medicine: other, title: MedicineText.fullName(other),
                              subtitle: "\(paper) · \(otherVerdict.headline)",
                              tone: otherVerdict.kind.tone, symbol: otherVerdict.kind.symbol)
        }
    }
    var showsRelated: Bool { !related.isEmpty }

    // MARK: - From your papers

    var quote: String { medicine.quote }
    var quoteSource: String { PlainText.source(paper: medicine.paper, page: medicine.quotePage) }

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

    // MARK: - Private

    // "Sun Oct 25 · 4 days before surgery"
    private func dayText(_ day: Int) -> String {
        "\(DayMath.shortDate(forDay: day, from: surgeryDate)) · \(DayMath.surgeryWords(forDay: day))"
    }
}
