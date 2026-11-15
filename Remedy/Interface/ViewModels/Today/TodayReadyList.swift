//
//  TodayReadyList.swift
//  Remedy
//
//  the optional last-dose question and the ready for surgery list
//

import Foundation
import SwiftData

// MARK: - Last-dose question on a stop day

// the patient's answer to did you take it today
enum LastDoseAnswer: String {
    case yes
    case no
}

// the question about a stopped medicine in the days before surgery
enum LastDoseQuestion {
    static let settingKey = "asksLastDose"
    static let noTitle = "No"
    static let yesFollowUp = "Your paper says not to. You may want to tell your surgeon\u{2019}s office."
    static let noFollowUp = "Good. Keep not taking it."
    static let callTitle = "Call"

    static func isOn(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: settingKey)
    }

    static func text(for medicine: MedicineInstruction) -> String {
        "Did you take any \(MedicineText.everydayName(medicine)) today?"
    }

    // the surgeon's office number if the papers have one
    static func officeURL(plan: CarePlan?) -> URL? {
        let contact = (plan?.contacts ?? []).first { $0.role == .careTeam && !$0.phone.isEmpty }
        return contact.flatMap { DayMath.phoneURL($0.phone) }
    }

    // "I Called" after a yes, kept for the day so the card goes away
    static func calledKey(_ medicine: MedicineInstruction, now: Date = AppClock.now()) -> String {
        let day = DayMath.calendar.startOfDay(for: now).timeIntervalSince1970
        return "stopCalled.\(medicine.name).\(Int(day))"
    }

    static func hasCalled(_ medicine: MedicineInstruction, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: calledKey(medicine))
    }

    static func markCalled(_ medicine: MedicineInstruction, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: calledKey(medicine))
    }

    static func answer(of medicine: MedicineInstruction) -> LastDoseAnswer? {
        medicine.lastTakenAnswer.flatMap(LastDoseAnswer.init(rawValue:))
    }
}

// one medicine's question on the stop card
struct StopQuestion: Identifiable {
    let medicine: MedicineInstruction
    let question: String
    let answer: LastDoseAnswer?
    let followUp: String
    let callURL: URL?

    var id: PersistentIdentifier { medicine.persistentModelID }
    var showsCall: Bool { answer == .yes && callURL != nil }

    // "Any Advil today?" for the one-row check on Today
    var shortQuestion: String { "Any \(shortName) today?" }

    var shortName: String { TodayViewModel.shortName(MedicineText.everydayName(medicine)) }

    // 89, the row and the dialog
    let tapToAnswer = "Tap to answer."
    let yesSomeTitle = "Yes, I Took Some"

    // "Your paper says to stop naproxen (Aleve) 7 days before surgery."
    var dialogDetail: String {
        let name = SimpleMedicinesScreen.lowerFirst(medicine.name)
        guard let start = medicine.startDay, start < 0 else { return "Your paper says to stop \(name) before surgery." }
        let days = -start == 1 ? "1 day" : "\(-start) days"
        return "Your paper says to stop \(name) \(days) before surgery."
    }

    // 90, after a yes until I Called
    var callEyebrow: String { "You took \(shortName) today" }
    let callTitle = "Call your surgeon\u{2019}s office"
    let callText = "Your paper says to stop it before surgery. The office will tell you what to do."
    let callButton = "Call Surgeon\u{2019}s Office"
    let addNumberButton = "Add Your Surgeon\u{2019}s Number"
    let calledButton = "I Called"

    var showsCallCard: Bool { answer == .yes && !LastDoseQuestion.hasCalled(medicine) }
}

// MARK: - Ready for surgery

// one row on the ready for surgery list
struct ReadyItem: Identifiable {
    enum Status: Equatable {
        case stoppedOnTime
        case tookLate
        case noAnswer
    }

    let id: String
    let name: String
    let status: Status
    let putAway: Bool

    var text: String {
        switch status {
        case .stoppedOnTime: return "Stopped on time"
        case .tookLate: return "Took some after the stop date"
        case .noAnswer: return putAway ? "No answer. You put it away." : "No answer"
        }
    }

    var symbol: String {
        switch status {
        case .stoppedOnTime: return "checkmark.circle.fill"
        case .tookLate: return "exclamationmark.circle.fill"
        case .noAnswer: return "questionmark.circle"
        }
    }

    var tone: Tone {
        switch status {
        case .stoppedOnTime: return .good
        case .tookLate: return .caution
        case .noAnswer: return .neutral
        }
    }

    var spokenLabel: String { "\(name). \(text)" }
}

// built only from what the patient recorded
struct ReadyList {
    let items: [ReadyItem]
    // lines from the papers about not eating or drinking
    let fastingLines: [String]
    // clock times from the papers or typed in, empty when none are known
    let timeLines: [String]
    let title = "Ready for surgery"
    let footer = "This shows only what you told Remedy. Follow your papers and your care team."

    // to-dos for the night before and what to bring, from the papers
    let tonight: [CareTask]
    let bring: [CareTask]
    // "Tomorrow, Thursday. Arrive by 7:30 AM."
    let lead: String

    var isEmpty: Bool { items.isEmpty && fastingLines.isEmpty && timeLines.isEmpty && tonight.isEmpty && bring.isEmpty }

    init(plan: CarePlan?) {
        guard let plan else {
            items = []
            fastingLines = []
            timeLines = []
            tonight = []
            bring = []
            lead = ""
            return
        }
        let isBring = { (task: CareTask) in ["bring", "pack"].contains { task.title.lowercased().contains($0) } }
        bring = plan.tasks.filter { isBring($0) && ($0.dueDay ?? 0) <= 0 && $0.paper == .beforeSurgery }
        tonight = plan.tasks.filter { $0.dueDay == -1 && !isBring($0) }
        if let surgeryDate = plan.surgeryDate {
            let arrival = DayChecklist.arrival(for: plan).map { " Arrive by \(DayMath.timeText(of: $0))." } ?? ""
            lead = "Surgery is \(TodayViewModel.weekday(surgeryDate)).\(arrival)"
        } else {
            lead = ""
        }
        let skipped = PaperCheckReport.of(plan).skipped
        let stops = plan.medicines.filter {
            $0.isConfirmed && $0.action == .stop
                && !skipped.contains($0.persistentModelID, onDay: $0.startDay ?? 0)
        }
        items = stops.map { medicine in
            let status: ReadyItem.Status
            switch LastDoseQuestion.answer(of: medicine) {
            case .no: status = .stoppedOnTime
            case .yes: status = .tookLate
            case nil: status = .noAnswer
            }
            return ReadyItem(id: medicine.name + "-ready", name: MedicineText.everydayName(medicine),
                             status: status, putAway: medicine.putAwayAt != nil)
        }
        fastingLines = plan.rules
            .filter { !$0.isAllowed && $0.paper == .beforeSurgery && Self.isFasting($0.title) }
            .map(\.title)
        timeLines = Self.timeLines(plan)
    }

    // food stop, last clear liquids and arrival, only the ones that can be worked out
    static func timeLines(_ plan: CarePlan) -> [String] {
        guard let surgeryDate = plan.surgeryDate else { return [] }
        let texts = plan.rules.flatMap { [$0.title, $0.quote] }
        var lines: [String] = []
        if let stop = FastingTimes.foodStop(surgeryDate: surgeryDate, texts: texts) {
            lines.append("No food after \(stop == DayMath.calendar.startOfDay(for: surgeryDate) ? "midnight" : DayMath.timeText(of: stop))")
        }
        let arrival = DayChecklist.arrival(for: plan)
        if let end = FastingTimes.clearLiquidsEnd(arrival: arrival, texts: texts) {
            lines.append("Last clear liquids at \(DayMath.timeText(of: end))")
        }
        if let arrival { lines.append("Arrive at \(DayMath.timeText(of: arrival))") }
        return lines
    }

    // MARK: - The pushed screen

    let medicinesHeader = "Medicines you stopped"
    let foodHeader = "Eating and drinking"
    let tonightHeader = "Tonight"
    let bringHeader = "Bring"

    // eating and drinking lines with clock times, arrival is in the lead
    var foodLines: [String] {
        fastingLines + timeLines.filter { !$0.hasPrefix("Arrive") }
    }

    // how many things there are to look over, for the row on Today
    var checkCount: Int { items.count + foodLines.count + tonight.count + bring.count }

    // id for a line ticked on this screen, kept for today only
    static func tickID(_ line: String) -> String { "ready-\(line)" }

    // read aloud
    var spokenText: String {
        var parts = [title, lead]
        parts += items.map(\.spokenLabel)
        parts += foodLines
        parts += tonight.map(\.title)
        if !bring.isEmpty { parts.append("Bring: " + PlainText.list(bring.map(\.title))) }
        parts.append(footer)
        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    // rules about eating and drinking go under fasting
    private static func isFasting(_ title: String) -> Bool {
        let lower = title.lowercased()
        return ["eat", "drink", "food", "fast"].contains { lower.contains($0) }
    }
}

extension TodayViewModel {

    // shown on the day before surgery
    var showsReady: Bool { layout == .beforeSurgery && day == -1 && !ready.isEmpty }
    var ready: ReadyList { ReadyList(plan: plan) }
}
