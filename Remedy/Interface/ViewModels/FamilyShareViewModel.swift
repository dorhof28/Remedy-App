//
//  FamilyShareViewModel.swift
//  Remedy
//
//  builds the printable pages for family for any day
//

import Foundation

// MARK: - Display data

// one line on the page "Ibuprofen " / "Stopped since Thu Oct 22"
struct FamilyLine: Identifiable, Hashable {
    let title: String
    let detail: String
    var hasCheckbox = false     // a box to tick on paper
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
    let left: [FamilyBlock]
    let right: [FamilyBlock]
    let footer: String
}

// which page to print
enum PrintKind: String, CaseIterable, Identifiable {
    case family         // medicines and plan on one page
    case day            // that day's doses with boxes to tick
    case medicines      // every medicine
    case journey        // every key day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .family: return "Overview"
        case .day: return "Day"
        case .medicines: return "Medicines"
        case .journey: return "Journey"
        }
    }

    var detail: String {
        switch self {
        case .family: return "Medicines, what not to do yet, visits and phone numbers."
        case .day: return "Every dose that day with a box to tick, plus what happens and who to call."
        case .medicines: return "Every medicine and what to do with it on that day."
        case .journey: return "Every key day from start to finish, with dates."
        }
    }

    // the journey is the same any day
    var usesDay: Bool { self != .journey }
}

// MARK: - ViewModel

struct FamilyShareViewModel {

    let plan: CarePlan?
    let now: Date               // the day being printed
    var kind: PrintKind = .family

    // a block shows at most this many lines so the page never runs over
    static let maxLines = 7
    static let maxLongLines = 14

    // MARK: - Words

    let title = "Share and print"
    let intro = "Pick a page and a day. Send it to someone helping you, or print it for the fridge."
    let dayLabel = "Day"
    let familyIntro = "One page with your medicines, what not to do yet, your visits and phone numbers. Send it to someone helping you, or print it for the fridge."
    let shareTitle = "Send or print"
    let makingText = "Making your page\u{2026}"
    let failedText = "Couldn\u{2019}t make the page. Try again."
    let doneTitle = "Done"

    var fileName: String { "Remedy \(kind.title.lowercased()) \(fileDate).pdf" }

    // only days inside the plan can be picked
    var dayRange: ClosedRange<Date> {
        guard let plan, let surgery = plan.surgeryDate else { return now...now }
        let range = Journey.range(for: plan, today: DayMath.dayOffset(of: now, from: surgery))
        return DayMath.date(forDay: range.lowerBound, from: surgery)...DayMath.date(forDay: range.upperBound, from: surgery)
    }

    // MARK: - The page

    var sheet: FamilySheet {
        switch kind {
        case .family: return familySheet
        case .day: return daySheet
        case .medicines: return medicinesSheet
        case .journey: return journeySheet
        }
    }

    // writes the page as a PDF the share sheet can send
    func makePDF() -> URL? {
        FamilySheetPDF.make(sheet, named: fileName)
    }

    // MARK: - Pages

    private var familySheet: FamilySheet {
        let medicines = MedicinesViewModel(plan: plan, now: now)
        let planVM = PlanViewModel(plan: plan, now: now)

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
                               openTasks.map { FamilyLine(title: $0.title, detail: $0.detail, hasCheckbox: true) }))
        }
        right += phoneBlock
        return page(title: "Remedy plan", left: left, right: right)
    }

    private var daySheet: FamilySheet {
        let planVM = PlanViewModel(plan: plan, now: now)
        var left: [FamilyBlock] = []
        var right: [FamilyBlock] = []

        // every dose that day grouped by time
        if let plan {
            let slots = DoseSchedule.slots(onDay: planVM.day, plan: plan, now: now)
            let times = Array(Set(slots.map(\.minute))).sorted()
            let lines = times.map { minute in
                FamilyLine(title: DayMath.timeText(minute),
                           detail: PlainText.list(slots.filter { $0.minute == minute }.map { MedicineText.fullName($0.medicine) }),
                           hasCheckbox: true)
            }
            if !lines.isEmpty { left.append(block("Doses", "pills.fill", .info, lines, max: Self.maxLongLines)) }

            // as needed medicines in effect that day
            let asNeeded = plan.medicines.filter { medicine in
                medicine.isConfirmed && medicine.action == .takeAsNeeded
                    && (medicine.startDay ?? Int.min) <= planVM.day && planVM.day <= (medicine.endDay ?? Int.max)
            }
            if !asNeeded.isEmpty {
                left.append(block("Only when needed", "cross.vial", .caution, asNeeded.map {
                    FamilyLine(title: MedicineText.fullName($0), detail: $0.onlyIf)
                }))
            }
        }

        // what happens that day
        let events = planVM.events(onDay: planVM.day)
        right.append(block("On this day", "calendar", .info,
                           events.isEmpty ? [FamilyLine(title: "Nothing new", detail: "Keep following the papers")]
                                          : events.map { FamilyLine(title: $0.title, detail: $0.detail) }))
        if planVM.showsNotYet {
            right.append(block(planVM.notYetTitle, "hand.raised.fill", .stop,
                               planVM.notYetRows.map { FamilyLine(title: $0.title, detail: $0.detail) }))
        }
        right += phoneBlock
        return page(title: "Remedy day", left: left, right: right)
    }

    private var medicinesSheet: FamilySheet {
        let medicines = MedicinesViewModel(plan: plan, now: now)
        let blocks = medicines.sections.map { section in
            block(section.title, section.symbol, section.tone, section.rows.map { row in
                FamilyLine(title: row.title, detail: medicineDetail(row))
            }, max: Self.maxLongLines)
        }
        // split the sections over two columns
        let half = (blocks.count + 1) / 2
        return page(title: "Remedy medicines", left: Array(blocks.prefix(half)), right: Array(blocks.dropFirst(half)))
    }

    private var journeySheet: FamilySheet {
        let planVM = PlanViewModel(plan: plan, now: now)
        let lines = planVM.overviewRows.map { row in
            FamilyLine(title: "\(row.stop.weekday), \(row.stop.month.capitalized) \(row.stop.dayNumber) \u{00B7} \(row.labelText)",
                       detail: row.stop.titles.joined(separator: " \u{00B7} "))
        }
        let half = (lines.count + 1) / 2
        let left = [block("Key days", "map", .info, Array(lines.prefix(half)), max: Self.maxLongLines)]
        let rest = Array(lines.dropFirst(half))
        let right = rest.isEmpty ? phoneBlock : [block("Key days (continued)", "map", .info, rest, max: Self.maxLongLines)]
        return page(title: "Remedy journey", left: left, right: right)
    }

    // MARK: - Private

    private var phoneBlock: [FamilyBlock] {
        let help = HelpViewModel(plan: plan)
        guard help.showsContacts else { return [] }
        return [block("Phone numbers", "phone.fill", .info, help.contactRows.map { FamilyLine(title: $0.name, detail: $0.phoneText) })]
    }

    // the same top and bottom on every page
    private func page(title: String, left: [FamilyBlock], right: [FamilyBlock]) -> FamilySheet {
        let today = TodayViewModel(plan: plan, now: now)
        let when = kind.usesDay ? DayMath.longDate(now) : ""
        let subtitle = [when, today.headerTitle].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        return FamilySheet(
            title: title,
            subtitle: subtitle,
            madeOn: "Made \(DayMath.shortDate(AppClock.now())). Dates move if the surgery date changes, so check the app for the latest.",
            left: left,
            right: right,
            footer: "From the papers the care team gave. Not medical advice. In an emergency, call 911.")
    }

    private func block(_ title: String, _ symbol: String, _ tone: Tone, _ lines: [FamilyLine], max: Int = FamilyShareViewModel.maxLines) -> FamilyBlock {
        let extra = lines.count - max
        return FamilyBlock(title: title, symbol: symbol, tone: tone,
                           lines: Array(lines.prefix(max)),
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

    private var fileDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: now)
    }
}
