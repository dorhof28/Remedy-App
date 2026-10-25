//
//  FamilyShareViewModel.swift
//  Remedy
//
//  builds the one page plan for family
//

import Foundation

// MARK: - Display data

// one line on the page "Ibuprofen " / "Stopped since Thu Oct 22"
struct FamilyLine: Identifiable, Hashable {
    let title: String
    let detail: String
    var id: String { title + "|" + detail }
}

// one block on the page "Don't take" + its lines
struct FamilyBlock: Identifiable {
    let title: String
    let symbol: String
    let tone: Tone
    let lines: [FamilyLine]
    let moreText: String        // "and 3 more in the app" ("" = none)
    var id: String { title }
}

// the whole page
struct FamilySheet {
    let title: String
    let subtitle: String
    let madeOn: String
    let left: [FamilyBlock]     // medicines
    let right: [FamilyBlock]    // plan, visits, numbers
    let footer: String
}

// MARK: - ViewModel

struct FamilyShareViewModel {

    let plan: CarePlan?
    let now: Date

    // a block shows at most this many lines so the page never runs over
    static let maxLines = 7

    // MARK: - Words

    let title = "Share with family"
    let intro = "One page with your medicines, what not to do yet, your visits and phone numbers. Send it to someone helping you, or print it for the fridge."
    let shareTitle = "Send or print"
    let makingText = "Making your page\u{2026}"
    let failedText = "Couldn\u{2019}t make the page. Try again."
    let doneTitle = "Done"
    let fileName = "Remedy plan.pdf"

    // MARK: - The page

    var sheet: FamilySheet {
        let today = TodayViewModel(plan: plan, now: now)
        let medicines = MedicinesViewModel(plan: plan, now: now)
        let planVM = PlanViewModel(plan: plan, now: now)
        let help = HelpViewModel(plan: plan)

        // left column every medicine section in the Medicines tab's order
        let left = medicines.sections.map { section in
            block(section.title, section.symbol, section.tone, section.rows.map { row in
                FamilyLine(title: row.title, detail: medicineDetail(row))
            })
        }

        // right column what matters to a helper
        var right: [FamilyBlock] = []
        if planVM.showsNotYet {
            right.append(block(planVM.notYetTitle, "hand.raised.fill", .stop,
                               planVM.notYetRows.map { FamilyLine(title: $0.title, detail: $0.detail) }))
        }
        if planVM.showsVisits {
            right.append(block(planVM.visitsTitle, "stethoscope", .info, planVM.visitRows.map {
                FamilyLine(title: $0.title, detail: "\($0.weekday), \($0.month.capitalized) \($0.dayNumber) · \($0.detail)")
            }))
        }
        let openTasks = planVM.taskRows.filter { !$0.isDone }
        if !openTasks.isEmpty {
            right.append(block(planVM.tasksTitle, "checklist", .caution,
                               openTasks.map { FamilyLine(title: $0.title, detail: $0.detail) }))
        }
        if help.showsContacts {
            right.append(block("Phone numbers", "phone.fill", .info,
                               help.contactRows.map { FamilyLine(title: $0.name, detail: $0.phoneText) }))
        }

        return FamilySheet(
            title: today.headerTitle.isEmpty ? "Remedy plan" : "Remedy plan \u{00B7} \(today.headerTitle)",
            subtitle: today.headerDetail,
            madeOn: "Made \(DayMath.shortDate(now)). Dates move if the surgery date changes, so check the app for the latest.",
            left: left,
            right: right,
            footer: "From the papers the care team gave. Not medical advice. In an emergency, call 911.")
    }

    // writes the page as a PDF the share sheet can send
    func makePDF() -> URL? {
        FamilySheetPDF.make(sheet, named: fileName)
    }

    // MARK: - Private

    private func block(_ title: String, _ symbol: String, _ tone: Tone, _ lines: [FamilyLine]) -> FamilyBlock {
        let extra = lines.count - Self.maxLines
        return FamilyBlock(title: title, symbol: symbol, tone: tone,
                           lines: Array(lines.prefix(Self.maxLines)),
                           moreText: extra > 0 ? "and \(extra) more in the app" : "")
    }

    // status or dose and times for every day pills
    private func medicineDetail(_ row: MedicineRow) -> String {
        let medicine = row.medicine
        guard medicine.action == .take, !medicine.timesOfDay.isEmpty else { return row.subtitle }
        return [MedicineText.howText(medicine), MedicineText.timesText(medicine)]
            .filter { !$0.isEmpty }
            .joined(separator: " \u{00B7} ")
    }
}
