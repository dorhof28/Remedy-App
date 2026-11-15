//
//  SharePlanViewModel.swift
//  Remedy
//
//  share plan (51, 102, 103): the five kinds, the options for each and the preview
//  both looks use it
//

import Foundation

// what goes on the shared page
enum ShareChoice: String, CaseIterable, Identifiable {
    case fullPlan, week, oneDay, medicineList, emergencyCard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullPlan: return "Full Plan"
        case .week: return "Week Plan"
        case .oneDay: return "One Day"
        case .medicineList: return "Medicine List"
        case .emergencyCard: return "Emergency Card"
        }
    }

    var subtitle: String? { self == .oneDay ? "With boxes to tick" : nil }

    // the page kind each choice is built from
    var kind: PrintKind {
        switch self {
        case .fullPlan: return .plan
        case .week, .oneDay: return .day
        case .medicineList: return .medicines
        case .emergencyCard: return .family
        }
    }
}

// the share sheet: which kind, the preview pages and the pdf
struct SharePlanViewModel {

    let plan: CarePlan?
    let now: Date
    var choice: ShareChoice = .fullPlan
    // the day picked for one day or the first day of the week
    var day: Date
    var leftOff: Set<PrintPart> = FamilyShareViewModel.planStartsOff

    // MARK: - Words

    let title = "Share Plan"
    let cancelTitle = "Cancel"
    let pickHeader = "What to share"
    let includeHeader = "Include"
    let optionsHeader = "Options"
    let includeFooter = "Your name is printed only if you turn it on. Shared files leave this iPhone."
    let dayTitle = "Day"
    let weekTitle = "Week"
    let makePDFTitle = "Make PDF"
    let previewTitle = "Preview"
    let shareTitle = "Share or Print"
    let makingText = "Making your PDF\u{2026}"
    let failedText = "Couldn\u{2019}t make the PDF. Try again."
    let tryAgainTitle = "Try Again"
    let emptyTitle = "Nothing to Share Yet"
    let addPapersTitle = "Add Papers"

    var hasPlan: Bool { plan != nil }

    private var base: FamilyShareViewModel {
        FamilyShareViewModel(plan: plan, now: choice == .fullPlan || choice == .medicineList ? now : day,
                             kind: choice.kind, leftOff: leftOff)
    }

    // MARK: - Options for each kind

    // full plan has the include switches, the rest only a few options
    var includeParts: [PrintPart] { choice == .fullPlan ? base.parts : [] }
    var showsDayRow: Bool { choice == .oneDay }
    var showsWeekRow: Bool { choice == .week }
    var showsPhonesSwitch: Bool { choice == .oneDay || choice == .week }
    var printedName: String? { base.printedName }
    var dayRange: ClosedRange<Date> { base.dayRange }

    func switchTitle(_ part: PrintPart) -> String { base.switchTitle(part) }

    // "Thu, Nov 12"
    var dayText: String { day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }

    // "Nov 12 to 18"
    var weekText: String {
        let days = weekDays
        guard let first = days.first, let last = days.last else { return dayText }
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        let sameMonth = DayMath.calendar.isDate(first, equalTo: last, toGranularity: .month)
        let end = sameMonth ? last.formatted(.dateTime.day()) : last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) to \(end)"
    }

    // seven days from the picked one, never past the end of the plan
    var weekDays: [Date] {
        let end = dayRange.upperBound
        return (0..<7).compactMap { DayMath.calendar.date(byAdding: .day, value: $0, to: day) }
            .filter { DayMath.calendar.startOfDay(for: $0) <= DayMath.calendar.startOfDay(for: end) }
    }

    // MARK: - The page

    var sheet: FamilySheet {
        switch choice {
        case .fullPlan:
            return base.sheet
        case .oneDay, .medicineList:
            return named(base.sheet)
        case .week:
            let pages = weekDays.map { date in
                FamilyShareViewModel(plan: plan, now: date, kind: .day, leftOff: leftOff).sheet
            }
            guard var first = pages.first else { return named(base.sheet) }
            first.more = Array(pages.dropFirst())
            return named(first)
        case .emergencyCard:
            return named(EmergencyInfoViewModel(plan: plan, now: now).cardSheet)
        }
    }

    // the name goes at the top only when switched on
    private func named(_ sheet: FamilySheet) -> FamilySheet {
        guard !leftOff.contains(.name), let name = printedName else { return sheet }
        var sheet = sheet
        sheet.title += " for \(name)"
        return sheet
    }

    var pageCount: Int { 1 + sheet.more.count }

    func pageText(_ page: Int) -> String { "Page \(page) of \(pageCount)" }

    var fileName: String {
        "Remedy \(choice.title.lowercased()) \(day.formatted(.iso8601.year().month().day())).pdf"
    }

    // changes whenever the page changes so the PDF is made again
    var pdfKey: String {
        "\(choice.rawValue)-\(DayMath.calendar.startOfDay(for: day).timeIntervalSince1970)-\(leftOff.map(\.rawValue).sorted())"
    }

    func makePDF() -> URL? {
        FamilySheetPDF.make(sheet, named: fileName)
    }
}
