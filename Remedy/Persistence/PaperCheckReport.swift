//
//  PaperCheckReport.swift
//  Remedy
//
//  one shared paper check for a plan: findings, words, and which medicines to leave out
//

import Foundation
import SwiftData

// the paper check for one plan, built once and cached until the plan changes
struct PaperCheckReport {

    // CheckItem.id is the index here
    let medicines: [MedicineInstruction]
    let result: PaperCheckResult
    // replaced lines, and while a finding is red the lines not followed, on the days they cover
    let skipped: SkippedLines

    // the check for this plan, only re-run when its papers lines or notes changed
    // a cheap fingerprint is checked first, so screens that redraw every minute never redo the slow check
    static func of(_ plan: CarePlan) -> PaperCheckReport {
        let key = plan.persistentModelID
        let print = PaperCheckInput.fingerprint(of: plan)
        if let hit = cache.get(key), hit.fingerprint == print {
            return PaperCheckReport(medicines: hit.medicines, result: hit.result)
        }
        let input = PaperCheckInput(plan: plan)
        let result = input.result
        cache.set(key, Entry(fingerprint: print, medicines: input.medicines, result: result))
        return PaperCheckReport(medicines: input.medicines, result: result)
    }

    private init(medicines: [MedicineInstruction], result: PaperCheckResult) {
        self.medicines = medicines
        self.result = result
        var skipped = SkippedLines()
        for (id, days) in result.notFollowedDays where medicines.indices.contains(id) {
            skipped.days[medicines[id].persistentModelID] = days
        }
        self.skipped = skipped
    }

    // open red first, then blue, for the medicine or any other name it goes by
    func findings(for medicine: MedicineInstruction) -> [Finding] {
        let names = MedicineIdentity.names(medicine.name, alsoKnownAs: medicine.alsoKnownAs)
        return result.findings
            .filter { $0.color != .green && $0.items.contains { MedicineIdentity.same($0.names, names) } }
            .sorted { ($0.color == .red && !$0.isResolved ? 0 : 1) < ($1.color == .red && !$1.isResolved ? 0 : 1) }
    }

    // the words for the most important finding on a medicine
    func message(for medicine: MedicineInstruction, surgeryDate: Date) -> (finding: Finding, message: CheckMessage)? {
        for finding in findings(for: medicine) {
            if let message = finding.message(surgeryDate: surgeryDate) { return (finding, message) }
        }
        return nil
    }

    // the line of the paper the app follows for a finding on a day, nil while an open circle follows none
    func followed(_ finding: Finding, onDay day: Int) -> MedicineInstruction? {
        let paperID = finding.followedPaperID(onDay: day)
        let item = finding.items.first { $0.paperID == paperID }
        return item.flatMap { medicines.indices.contains($0.id) ? medicines[$0.id] : nil }
    }

    // MARK: - Cache

    // a cached report and the plan fingerprint it was built for
    private struct Entry {
        let fingerprint: Int
        let medicines: [MedicineInstruction]
        let result: PaperCheckResult
    }

    // thread safe cache, the widget and reminders read it off the main thread
    private final class Cache {
        private let lock = NSLock()
        private var entries: [PersistentIdentifier: Entry] = [:]

        func get(_ key: PersistentIdentifier) -> Entry? {
            lock.lock()
            defer { lock.unlock() }
            return entries[key]
        }

        func set(_ key: PersistentIdentifier, _ entry: Entry) {
            lock.lock()
            defer { lock.unlock() }
            entries[key] = entry
        }
    }

    private static let cache = Cache()
}

// the one place the plan's paper check meets the dose, reminder and ask rules
extension DoseSchedule {
    // dose rows with the paper check applied
    static func slotsWithCheck(onDay day: Int, plan: CarePlan, now: Date) -> [DoseSlot] {
        slots(onDay: day, plan: plan, now: now, skipped: PaperCheckReport.of(plan).skipped)
    }
}

extension ReminderPlan {
    // reminders with the paper check applied
    static func itemsWithCheck(for plan: CarePlan, now: Date, checkedInDays: Set<Int> = []) -> [ReminderItem] {
        items(for: plan, now: now, skipped: PaperCheckReport.of(plan).skipped,
              checkInMinute: plan.checkInMinute, checkedInDays: checkedInDays)
    }
}

extension AskAnswers {
    // ask answers that follow the paper check
    static func answerWithCheck(_ question: String, plan: CarePlan, today: Int, now: Date) -> AskAnswer {
        let report = PaperCheckReport.of(plan)
        return answer(question, plan: plan, today: today, now: now) { medicine, surgeryDate in
            if let found = report.message(for: medicine, surgeryDate: surgeryDate) {
                return (found.message, report.followed(found.finding, onDay: today))
            }
            // the surgery team's paper covers it, answer from the line followed today with no note
            return report.findings(for: medicine).first { $0.rule == .surgeryTeamCovers }
                .map { (nil, report.followed($0, onDay: today)) }
        }
    }
}
