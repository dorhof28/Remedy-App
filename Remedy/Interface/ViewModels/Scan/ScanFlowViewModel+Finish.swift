//
//  ScanFlowViewModel+Finish.swift
//  Remedy
//
//  the finish screen and saving the plan
//

import Foundation
import SwiftData

extension ScanFlowViewModel {

    var finishTitle: String { "Your plan is ready" }
    var surgeryDateTitle: String { "When is your surgery?" }
    // asks every time so a visit date on the papers never becomes the surgery date
    var surgeryDateDetail: String {
        if let found = draft?.surgeryDate {
            return "Your papers mention \(DayMath.longDate(found)). Make sure that\u{2019}s the day of the operation, not a visit."
        }
        return "Your papers count days from surgery (\u{201C}4 days before\u{201D}). Remedy needs the date to give real dates."
    }
    var startButton: String { "Start my plan" }
    var cancelButton: String { "Cancel" }

    var confirmedCount: Int { cards.count - removedIDs.count }
    var finishDetail: String {
        let checked = confirmedCount + removedIDs.count
        var text = "You checked \(PlainText.count(checked, "item"))."
        let kept = confirmedCount
        if removedIDs.isEmpty {
            text += kept == 1 ? " It\u{2019}s in your plan." : " All \(kept) are in your plan."
        } else {
            text += " \(kept) \(kept == 1 ? "is" : "are") in your plan, \(removedIDs.count) \(removedIDs.count == 1 ? "was" : "were") left out."
        }
        return text
    }

    // the rows under "Your plan is ready": medicines, stop items, what was left out
    struct FinishRow: Identifiable {
        let id: String
        let symbol: String
        let tone: Tone
        let title: String
        let detail: String
    }

    var finishRows: [FinishRow] {
        guard let draft else { return [] }
        let kept = draft.medicines.filter { !removedIDs.contains($0.id) }
        let taking = kept.filter { $0.action != .stop }
        let stops = kept.filter { $0.action == .stop }
        var rows: [FinishRow] = []
        if !taking.isEmpty {
            let daily = taking.filter { $0.action == .take || $0.action == .okToTake }.count
            let needed = taking.filter { $0.action == .takeAsNeeded }.count
            let parts = [daily > 0 ? "\(daily) every day" : "", needed > 0 ? "\(needed) only when needed" : ""]
                .filter { !$0.isEmpty }
            rows.append(FinishRow(id: "medicines", symbol: "pill", tone: .info,
                                  title: PlainText.count(taking.count, "medicine"), detail: parts.joined(separator: ", ")))
        }
        if !stops.isEmpty {
            rows.append(FinishRow(id: "stops", symbol: "nosign", tone: .stop,
                                  title: PlainText.count(stops.count, "stop item"),
                                  detail: PlainText.list(stops.map { lowerAfterFirst($0, in: stops) })))
        }
        let left = draft.medicines.filter { removedIDs.contains($0.id) }.map(\.name)
            + draft.rules.filter { removedIDs.contains($0.id) }.map(\.title)
            + draft.tasks.filter { removedIDs.contains($0.id) }.map(\.title)
            + draft.appointments.filter { removedIDs.contains($0.id) }.map(\.title)
        if !left.isEmpty {
            rows.append(FinishRow(id: "left", symbol: "info.circle", tone: .neutral, title: "Left out: \(left.count)",
                                  detail: "\(PlainText.list(left)). You can add \(left.count == 1 ? "it" : "them") later."))
        }
        return rows
    }

    // "Naproxen (Aleve), fish oil": the first name as written, the rest in lower case
    private func lowerAfterFirst(_ medicine: DraftMedicine, in all: [DraftMedicine]) -> String {
        let brand = medicine.alsoKnownAs.first { $0 != medicine.name.lowercased() }.map { " (\(PlainText.upperFirst($0)))" } ?? ""
        let name = medicine.name + (medicine.isGroup ? "" : brand)
        return medicine.id == all.first?.id ? name : PlainText.lowerFirst(name)
    }

    var doneButton: String { "Done" }

    var needsSurgeryDate: Bool { !planHasSurgeryDate }

    // starting without picking asks once so today is never used by accident
    var asksToCheckDate: Bool { needsSurgeryDate && !hasPickedDate }
    var checkDateTitle: String { "Is your surgery on \(DayMath.longDate(surgeryDate))?" }
    var checkDateYes: String { "Yes, start my plan" }
    var checkDateNo: String { "Pick the date" }

    // saves only the confirmed items, true when the flow is over
    func save(in context: ModelContext) -> Bool {
        // a double tap must never save the plan twice
        guard !didSave else { return whatChanged == nil }
        guard var draft else { return true }
        didSave = true
        if needsSurgeryDate {
            draft.surgeryDate = surgeryDate
        }
        // a skipped page is never forgotten, it becomes a to-do
        for title in skippedPageTasks {
            draft.tasks.append(.confirmedTodo(title))
        }
        let plan = PlanImporter.save(draft, in: context)
        // the check-in time picked in setup goes on the new plan
        if !isAddingPapers, let minute = defaults.object(forKey: OnboardingViewModel.checkInKey) as? Int {
            plan.checkInMinute = minute
            defaults.removeObject(forKey: OnboardingViewModel.checkInKey)
            context.saveNow()
        }
        // a yes on the calendar step fills the Remedy calendar now the plan exists
        if !isAddingPapers, defaults.bool(forKey: CalendarService.planOnKey) {
            // read the plan now, the task may run after it is gone
            let wanted = CalendarService.snapshot(of: plan)
            Task { await CalendarService.sync(wanted, defaults: defaults) }
        }
        whatChanged = WhatChangedViewModel(plan: plan)
        guard whatChanged != nil else { return true }
        Motion.run { step = .whatChanged }
        return false
    }
}
