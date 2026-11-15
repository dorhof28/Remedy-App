//
//  FamilyShareViewModel.swift
//  Remedy
//
//  builds the printable pages for family for any day
//

import Foundation
import SwiftData

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
    var title: String
    let symbol: String
    let tone: Tone
    let lines: [FamilyLine]
    let moreText: String        // "and 3 more in the app" ("" = none)
    var part: PrintPart = .plan // what the patient can leave off the page
    var id: String { title }
}

// parts of a page the patient can leave off
enum PrintPart: String, CaseIterable, Identifiable {
    case medicines, plan, todos, phones
    // the share plan sheet's extra switches
    case rules, checkIns, doseLog, name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medicines: return "Medicines"
        case .plan: return "Visits and instructions"
        case .todos: return "To-do boxes"
        case .phones: return "Phone numbers"
        case .rules: return "Rules"
        case .checkIns: return "Check-ins and photos"
        case .doseLog: return "Dose log"
        case .name: return "Print my name at the top"
        }
    }

    var symbol: String {
        switch self {
        case .medicines: return "pills.fill"
        case .plan: return "calendar"
        case .todos: return "checklist"
        case .phones: return "phone.fill"
        case .rules: return "list.bullet"
        case .checkIns: return "heart"
        case .doseLog: return "clock"
        case .name: return "person.crop.circle"
        }
    }
}

// the whole page
struct FamilySheet {
    var title: String
    let subtitle: String
    let madeOn: String
    var left: [FamilyBlock]
    var right: [FamilyBlock]
    let footer: String
    var pageText: String = ""           // "Page 1 of 2" ("" = one page")
    var cover: [FamilyLine] = []        // procedure, surgery date, who to call
    var more: [FamilySheet] = []        // later pages of the same document
}

// which page to print
enum PrintKind: String, CaseIterable, Identifiable {
    case family         // medicines and plan on one page
    case day            // that day's doses with boxes to tick
    case medicines      // every medicine
    case journey        // every key day
    case everything     // all of it, over two pages
    case plan           // share plan: the parts switched on, check-ins and dose log on page two

    var id: String { rawValue }

    var title: String {
        switch self {
        case .family: return "Medicines overview"
        case .day: return "Day"
        case .medicines: return "Medicines"
        case .journey: return "Journey"
        case .everything: return "Everything"
        case .plan: return "Plan"
        }
    }

    var detail: String {
        switch self {
        case .family: return "Medicines, what not to do yet, visits and phone numbers."
        case .day: return "Every dose that day with a box to tick, plus what happens and who to call."
        case .medicines: return "Every medicine and what to do with it on that day."
        case .journey: return "Every key day from start to finish, with dates."
        case .everything: return "Medicines, visits, instructions, phone numbers, the ready list and anything to ask the office."
        case .plan: return "Medicines, rules, visits and to-dos, with check-ins and the dose log if you turn them on."
        }
    }

    // the journey is the same any day
    var usesDay: Bool { self != .journey && self != .plan }

    // the only two pages offered on screen
    static let choices: [PrintKind] = [.family, .day]
}

// MARK: - ViewModel

// the family sheet for one day, a week or the whole plan, as blocks ready to print
struct FamilyShareViewModel {

    let plan: CarePlan?
    let now: Date               // the day being printed
    var kind: PrintKind = .family
    // parts the patient left off the page
    var leftOff: Set<PrintPart> = []

    // a block shows at most this many lines
    // long lists carry on over more pages so only a very long one is cut
    static let maxLines = 30
    static let maxLongLines = 60

    // MARK: - Words

    let title = "Share with family"
    let dayLabel = "Day"
    let shareTitle = "Share or print"
    let pageTitle = "Page"
    let pickTitle = "What to share"
    let choices = PrintKind.choices
    let makingText = "Making your page\u{2026}"
    let failedText = "Couldn\u{2019}t make the page. Try again."
    let doneTitle = "Done"

    // changes whenever the page changes so the PDF is made again
    func pdfKey(day: Date) -> String {
        "\(kind.rawValue)-\(Calendar.current.startOfDay(for: day).timeIntervalSince1970)-\(leftOff.map(\.rawValue).sorted())"
    }

    var fileName: String { "Remedy \(kind.title.lowercased()) \(fileDate).pdf" }

    // only days inside the plan can be picked
    var dayRange: ClosedRange<Date> {
        guard let plan, let surgery = plan.surgeryDate else { return now...now }
        let range = Journey.range(for: plan, today: DayMath.dayOffset(of: now, from: surgery))
        return DayMath.date(forDay: range.lowerBound, from: surgery)...DayMath.date(forDay: range.upperBound, from: surgery)
    }

    // MARK: - The page

    var sheet: FamilySheet {
        let full: FamilySheet
        switch kind {
        case .family: full = familySheet
        case .day: full = daySheet
        case .medicines: full = medicinesSheet
        case .journey: full = journeySheet
        case .everything: full = everythingSheet
        case .plan: full = planSheet
        }
        return leaving(leftOff, from: full)
    }

    // which parts this kind of page has, so only real choices are offered
    var parts: [PrintPart] {
        switch kind {
        case .family, .everything: return [.medicines, .plan, .todos, .phones]
        case .plan: return [.medicines, .rules, .plan, .checkIns, .doseLog]
        case .day: return [.medicines, .plan, .phones]
        case .medicines: return []
        case .journey: return [.phones]
        }
    }

    // only the phone numbers switch is offered
    var showsPhonesSwitch: Bool { parts.contains(.phones) }

    // takes the left off parts out of every page
    func leaving(_ off: Set<PrintPart>, from sheet: FamilySheet) -> FamilySheet {
        guard !off.isEmpty else { return sheet }
        var sheet = sheet
        sheet.left = sheet.left.filter { !off.contains($0.part) }
        sheet.right = sheet.right.filter { !off.contains($0.part) }
        // a later page with nothing left on it is dropped
        sheet.more = sheet.more.map { leaving(off, from: $0) }.filter { !$0.left.isEmpty || !$0.right.isEmpty }
        return sheet
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
            }, part: .medicines)
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
                               openTasks.map { FamilyLine(title: $0.title, detail: $0.detail, hasCheckbox: true) }, part: .todos))
        }
        right += phoneBlock
        return page(title: "Remedy plan", left: left, right: right)
    }

    // two pages with every part of the plan
    private var everythingSheet: FamilySheet {
        let medicines = MedicinesViewModel(plan: plan, now: now)
        let planVM = PlanViewModel(plan: plan, now: now)
        let help = HelpViewModel(plan: plan)

        // page one medicines with their stops and restarts, then visits and rules
        let medicineBlocks = medicines.sections.map { section in
            block(section.title, section.symbol, section.tone, section.rows.map { row in
                FamilyLine(title: row.title, detail: medicineDetail(row))
            }, max: Self.maxLongLines, part: .medicines)
        }
        var rightOne: [FamilyBlock] = []
        if planVM.showsVisits {
            rightOne.append(block(planVM.visitsTitle, "stethoscope", .info, planVM.visitRows.map {
                FamilyLine(title: $0.title, detail: "\($0.weekday), \($0.month.capitalized) \($0.dayNumber) \u{00B7} \($0.detail)")
            }))
        }
        for (title, symbol, tone, rows) in [
            (planVM.notYetTitle, "xmark.circle.fill", Tone.stop, planVM.notYetRows),
            (planVM.okTitle, "checkmark.circle.fill", Tone.good, planVM.okRows),
            (planVM.comingUpTitle, "calendar", Tone.info, planVM.comingUpRows),
        ] where !rows.isEmpty {
            rightOne.append(block("Instructions: \(title)", symbol, tone, rows.map {
                FamilyLine(title: $0.title, detail: [$0.headline, $0.detail].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
            }))
        }

        // page two the ready list, phone numbers and open paper checks
        // same ready list as the screen: times, stops with the answers, then open to do items
        var leftTwo: [FamilyBlock] = []
        let readyList = ReadyList(plan: plan)
        var ready = readyList.timeLines.map { FamilyLine(title: $0, detail: "", hasCheckbox: true) }
        ready += readyList.items.map { FamilyLine(title: "Stop \($0.name)", detail: $0.text, hasCheckbox: true) }
        ready += readyList.fastingLines.map { FamilyLine(title: $0, detail: "", hasCheckbox: true) }
        ready += planVM.taskRows.filter { !$0.isDone }.map { FamilyLine(title: $0.title, detail: $0.detail, hasCheckbox: true) }
        if !ready.isEmpty { leftTwo.append(block("Ready list", "checklist", .caution, ready, max: Self.maxLongLines, part: .todos)) }

        var rightTwo: [FamilyBlock] = []
        if help.showsContacts { rightTwo += phoneBlock }
        let cards = PaperCheckViewModel(plan: plan, now: now).redCards
        if !cards.isEmpty {
            rightTwo.append(block("Ask the office", "exclamationmark.triangle.fill", .stop, cards.map {
                FamilyLine(title: $0.finding.medicine.capitalized, detail: $0.headline, hasCheckbox: true)
            }))
        }

        var first = page(title: "Remedy everything", left: medicineBlocks, right: rightOne)
        first.more = [page(title: "Remedy everything (page 2)", left: leftTwo, right: rightTwo)]
        return first
    }

    // MARK: - Share plan (screen 51)

    let cancelTitle = "Cancel"
    let makePDFTitle = "Make PDF"
    let includeFooter = "Your name is printed only if you turn it on. Shared files leave this iPhone."
    // off until the patient turns them on
    static let planStartsOff: Set<PrintPart> = [.checkIns, .doseLog, .name]

    // the switch's words for each part on this sheet
    func switchTitle(_ part: PrintPart) -> String {
        switch part {
        case .medicines: return "Medicines and times"
        case .plan: return "Visits and to-dos"
        default: return part.title
        }
    }

    // the first name saved in settings, nil hides the switch
    var printedName: String? { PatientNames.saved.first }

    private var planSheet: FamilySheet {
        let medicines = MedicinesViewModel(plan: plan, now: now)
        let planVM = PlanViewModel(plan: plan, now: now)
        let left = medicines.sections.map { section in
            block(section.title, section.symbol, section.tone, section.rows.map { row in
                FamilyLine(title: row.title, detail: medicineDetail(row))
            }, max: Self.maxLongLines, part: .medicines)
        }
        var right: [FamilyBlock] = []
        let rules = planVM.activeRuleRows(onDay: planVM.day) + planVM.comingUpRows
        if !rules.isEmpty {
            right.append(block("Rules", "list.bullet", .info, rules.map {
                FamilyLine(title: $0.title, detail: [$0.headline, $0.detail].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
            }, part: .rules))
        }
        if planVM.showsVisits {
            right.append(block(planVM.visitsTitle, "calendar", .info, planVM.visitRows.map {
                FamilyLine(title: $0.title, detail: "\($0.weekday), \($0.month.capitalized) \($0.dayNumber) \u{00B7} \($0.detail)")
            }, part: .plan))
        }
        let open = planVM.taskRows.filter { !$0.isDone }
        if !open.isEmpty {
            right.append(block(planVM.tasksTitle, "checklist", .caution,
                               open.map { FamilyLine(title: $0.title, detail: $0.detail, hasCheckbox: true) }, part: .plan))
        }
        right += phoneBlock

        var leftTwo: [FamilyBlock] = []
        var rightTwo: [FamilyBlock] = []
        if let plan, let surgery = plan.surgeryDate {
            let checkIns = (try? plan.modelContext?.fetch(FetchDescriptor<CheckIn>())) ?? []
            let lines = checkIns.sorted { $0.day < $1.day }.map { checkIn in
                FamilyLine(title: DayMath.shortDate(forDay: checkIn.day, from: surgery),
                           detail: (["Pain \(checkIn.pain) of 10"] + checkIn.signs + [checkIn.note].filter { !$0.isEmpty })
                            .joined(separator: " \u{00B7} "))
            }
            let photos = ((try? plan.modelContext?.fetchCount(FetchDescriptor<PhotoEntry>())) ?? 0)
            let photoLine = photos == 0 ? [] : [FamilyLine(title: "Photos", detail: PhotoLogLogic.countText(photos) + " in the app")]
            if !lines.isEmpty || !photoLine.isEmpty {
                leftTwo.append(block("Check-ins", "heart", .info, lines + photoLine, max: Self.maxLongLines, part: .checkIns))
            }
            let logs = plan.medicines.flatMap(\.doseLogs).sorted { $0.scheduledFor > $1.scheduledFor }
            if !logs.isEmpty {
                rightTwo.append(block("Dose log", "clock", .info, logs.map { log in
                    FamilyLine(title: "\(DayMath.shortDate(log.scheduledFor)) \(DayMath.timeText(of: log.scheduledFor))",
                               detail: [log.medicine.map { MedicineText.fullName($0) } ?? "", log.status == .taken ? "Taken" : "Skipped"]
                                .filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
                }, max: Self.maxLongLines, part: .doseLog))
            }
        }
        let name = leftOff.contains(.name) ? nil : printedName
        var first = page(title: name.map { "Remedy plan for \($0)" } ?? "Remedy plan", left: left, right: right)
        if !leftTwo.isEmpty || !rightTwo.isEmpty {
            first.more = [page(title: "Remedy plan (page 2)", left: leftTwo, right: rightTwo)]
        }
        return first
    }

    private var daySheet: FamilySheet {
        let planVM = PlanViewModel(plan: plan, now: now)
        var left: [FamilyBlock] = []
        var right: [FamilyBlock] = []

        // every dose that day grouped by time
        if let plan {
            let slots = DoseSchedule.slotsWithCheck(onDay: planVM.day, plan: plan, now: now)
            let times = Array(Set(slots.map(\.minute))).sorted()
            let lines = times.map { minute in
                FamilyLine(title: DayMath.timeText(minute),
                           detail: PlainText.list(slots.filter { $0.minute == minute }.map { MedicineText.fullName($0.medicine) }),
                           hasCheckbox: true)
            }
            if !lines.isEmpty { left.append(block("Doses", "pills.fill", .info, lines, max: Self.maxLongLines, part: .medicines)) }

            // as needed medicines in effect that day
            let asNeeded = plan.medicines.filter { medicine in
                medicine.isConfirmed && medicine.action == .takeAsNeeded
                    && (medicine.startDay ?? Int.min) <= planVM.day && planVM.day <= (medicine.endDay ?? Int.max)
            }
            if !asNeeded.isEmpty {
                left.append(block("Only when needed", "cross.vial", .caution, asNeeded.map {
                    FamilyLine(title: MedicineText.fullName($0), detail: $0.onlyIf)
                }, part: .medicines))
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
            }, max: Self.maxLongLines, part: .medicines)
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
        return [block("Phone numbers", "phone.fill", .info, help.contactRows.map { FamilyLine(title: $0.name, detail: $0.phoneText) }, part: .phones)]
    }

    // the same top and bottom on every page
    private func page(title: String, left: [FamilyBlock], right: [FamilyBlock]) -> FamilySheet {
        let today = TodayViewModel(plan: plan, now: now)
        let when = kind.usesDay ? DayMath.longDate(now) : ""
        let subtitle = [when, today.headerTitle].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        let cover = coverLines
        return FamilySheet(
            title: title,
            subtitle: subtitle,
            madeOn: "Made \(DayMath.shortDate(AppClock.now())). Dates move if the surgery date changes, so check the app for the latest.",
            left: left,
            right: right,
            footer: "From the papers the care team gave. Not medical advice. In an emergency, call 911.",
            cover: cover)
    }

    // procedure, surgery date and who to call at the top of every page
    private var coverLines: [FamilyLine] {
        guard let plan else { return [] }
        var lines: [FamilyLine] = []
        if !plan.procedure.isEmpty { lines.append(FamilyLine(title: "Procedure", detail: plan.procedure)) }
        if let date = plan.surgeryDate { lines.append(FamilyLine(title: "Surgery", detail: DayMath.longDate(date))) }
        if let contact = HelpViewModel(plan: plan).contactRows.first {
            lines.append(FamilyLine(title: "Call", detail: "\(contact.name) \(contact.phoneText)"))
        }
        return lines
    }

    // a block with a more line when it has too many lines
    private func block(_ title: String, _ symbol: String, _ tone: Tone, _ lines: [FamilyLine], max: Int = FamilyShareViewModel.maxLines, part: PrintPart = .plan) -> FamilyBlock {
        let extra = lines.count - max
        return FamilyBlock(title: title, symbol: symbol, tone: tone,
                           lines: Array(lines.prefix(max)),
                           moreText: extra > 0 ? "and \(extra) more in the app" : "", part: part)
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
        now.formatted(.dateTime.month(.abbreviated).day())
    }
}
