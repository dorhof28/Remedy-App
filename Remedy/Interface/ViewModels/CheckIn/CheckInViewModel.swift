//
//  CheckInViewModel.swift
//  Remedy
//
//  daily recovery check in for both looks
//

import Foundation
import SwiftData

// one number to call
struct CheckInCall: Identifiable {
    let phoneText: String
    let phoneURL: URL?
    let reason: String      // the signs ticked for this number
    var messageURL: URL? = nil
    var emailURL: URL? = nil
    var id: String { phoneText }
}

// the daily check-in: pain, warning signs and a note for today's plan day
struct CheckInViewModel {

    let plan: CarePlan?
    let day: Int

    let title = "Daily check-in"
    // the sheet title and the row on Today
    let shortTitle = "Check-in"
    let noteHeader = "Anything to add?"
    let notePlaceholder2 = "Write a note for yourself or your doctor"
    let saveShort = "Save"
    let painTitle = "How much does it hurt?"
    let painLow = "0 \u{00B7} No pain"
    let painHigh = "10 \u{00B7} Worst"
    let photoTitle = "Add a Photo of the Cut"
    let photoDetail = "Stays on this iPhone"
    let painFooter = "Pain of 8 or more shows a Call Surgeon\u{2019}s Office button here."
    let callOfficeTitle = "Call Surgeon\u{2019}s Office"
    let cancelTitle = "Cancel"
    let sheetTitle = "Check-In"

    // high pain shows the call button, a medical line kept in one place
    static let callPainLevel = 8
    func showsPainCall(_ pain: Int?) -> Bool { (pain ?? 0) >= Self.callPainLevel }
    let painScale = "0 is no pain. 10 is the worst."
    let signsTitle = "Do you have any of these?"
    let signsHint = "These come from your own papers."
    let noSignsText = "Your papers don\u{2019}t list warning signs. If something worries you, call your care team."
    let noteTitle = "Anything to add? (optional)"
    let saveTitle = "Save check-in"
    let savedText = "Saved. See you tomorrow."
    let callTitle = "Call now"
    // short words for the compact screen
    let worriedTitle = "Worried? Call your surgeon"
    let notePrompt = "Add a note (optional)"
    let doneTitle = "Done"
    let notePlaceholder = "Type here"

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        if let plan, let today = DoseSchedule.today(for: plan, now: now) {
            day = today
        } else {
            day = 0
        }
    }

    // MARK: - Signs from the papers

    var careTeamPhone: String? {
        (plan?.contacts ?? []).first { $0.role == .careTeam && !$0.phone.isEmpty }?.phone
    }

    var signs: [WarningSign] {
        var seen = Set<String>()
        return (plan?.rules ?? []).compactMap { rule in
            guard WarningSigns.isWarning(title: rule.title, condition: rule.condition,
                                         quote: rule.quote, isAllowed: rule.isAllowed) else { return nil }
            let sign = WarningSigns.sign(title: rule.title, condition: rule.condition,
                                         quote: rule.quote, careTeamPhone: careTeamPhone)
            return seen.insert(sign.text).inserted ? sign : nil
        }
    }

    // fixed line always shown, signs picked by keyword can miss one
    let worriedLine = "Call your surgeon if you are worried."
    let noNumberText = "No phone number was found on your papers. Look on your discharge papers."

    // the care team number for the fixed line, nil when none on the papers
    var worriedCall: CheckInCall? {
        guard let phone = careTeamPhone, let url = DayMath.phoneURL(phone) else { return nil }
        let contact = (plan?.contacts ?? []).first { $0.role == .careTeam && !$0.phone.isEmpty }
        return CheckInCall(phoneText: PhoneFormat.text(phone), phoneURL: url, reason: worriedLine,
                           messageURL: ContactLinks.messageURL(phone: phone),
                           emailURL: contact.flatMap { ContactLinks.emailURL(for: $0) })
    }

    // the call card for ticked signs
    func calls(ticked: Set<String>) -> [CheckInCall] {
        let chosen = signs.filter { ticked.contains($0.text) }
        return WarningSigns.numbers(for: chosen).map { phone in
            let reasons = chosen.filter { $0.phone == phone }.map(\.text)
            return CheckInCall(phoneText: phone == "911" ? "911" : PhoneFormat.text(phone),
                               phoneURL: DayMath.phoneURL(phone),
                               reason: PlainText.list(reasons))
        }
    }

    // 91 words
    let signsHeader = "Any of these today?"
    let signsFooter = "From your paper. Pain scale is above; note and photo are below."
    let callOfficeInstead = "Call Your Doctor\u{2019}s Office"
    let addNumberTitle = "Add a Number"

    // "You ticked: calf pain, swelling or warmth"
    func tickedEyebrow(_ reason: String) -> String { "You ticked: \(reason.lowercased())" }

    // the paper's own words for a sign, never a rating or advice
    func paperSays(_ signText: String) -> String {
        let rule = (plan?.rules ?? []).first { rule in
            WarningSigns.sign(title: rule.title, condition: rule.condition, quote: rule.quote, careTeamPhone: careTeamPhone).text == signText
        }
        let words = (rule?.quote.isEmpty == false ? rule?.quote : rule?.title) ?? signText
        return "Your paper says: \u{201C}\(words)\u{201D}"
    }

    // ticked signs with no number anywhere
    func hasUnreachable(ticked: Set<String>) -> Bool {
        signs.contains { ticked.contains($0.text) && ($0.phone ?? "").isEmpty }
    }

    // MARK: - Saved

    // today only after surgery
    var isAvailable: Bool { plan != nil && day >= 1 }

    // today's saved check-in, if there is one
    func today(in context: ModelContext) -> CheckIn? {
        let day = day
        let found = try? context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.day == day }))
        return found?.first
    }

    // a second check-in on the same day edits the first, pain is clamped to 0 to 10
    func save(pain: Int, ticked: Set<String>, note: String, in context: ModelContext) {
        let signTexts = signs.map(\.text).filter { ticked.contains($0) }
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = today(in: context) {
            existing.pain = min(max(pain, 0), 10)
            existing.signs = signTexts
            existing.note = clean
            existing.editedAt = Date()
        } else {
            context.insert(CheckIn(day: day, pain: min(max(pain, 0), 10), signs: signTexts, note: clean))
        }
        context.saveNow()
        // today's reminder is not needed now
        let plan = plan
        Task { await NotificationService.shared.refresh(plan: plan, now: AppClock.now()) }
    }

    // MARK: - Check-in time

    var checkInMinute: Int? { plan?.checkInMinute }

    // "Check-in · 9:00 AM" or just "Check-in"
    var rowTitle: String {
        checkInMinute.map { "\(shortTitle) \u{00B7} \(CheckInTime.text(minute: $0))" } ?? shortTitle
    }

    // today's check-in time as a date, nil with no time set
    func timeToday(now: Date) -> Date? {
        guard let minute = checkInMinute else { return nil }
        return CheckInTime.date(minute: minute, onDayOf: now)
    }

    // nil turns the check-in reminder off
    func setTime(_ minute: Int?, in context: ModelContext) {
        plan?.checkInMinute = minute.map(CheckInTime.clamped)
        context.saveNow()
    }

    // the one-time ask on Today
    var shouldPromptForTime: Bool {
        guard let plan else { return false }
        return CheckInTime.shouldPrompt(minute: plan.checkInMinute, today: day,
                                        dismissals: plan.checkInPromptDismissals, lastDismissedDay: plan.checkInPromptLastDay)
    }

    // counts how often the time prompt was closed so it stops asking
    func dismissTimePrompt(in context: ModelContext) {
        plan?.checkInPromptDismissals += 1
        plan?.checkInPromptLastDay = day
        context.saveNow()
    }
}

// MARK: - Pain picture
// a plain word and a colour for the number, only a description never advice

extension CheckInViewModel {

}

// MARK: - Check-ins over time with photos

// one dot on the pain chart, the last check-in of a day
struct CheckInPoint: Identifiable, Equatable {
    let date: Date
    let pain: Int
    var id: Date { date }
}

extension CheckInViewModel {

    static let historyTitle = "Check-ins"
    static let chartEmpty = "Your pain chart shows here after your first check-in."
    static let comparePhotosTitle = "Compare or share photos"

    // one point per day, oldest first for the chart
    static func painPoints(_ checkIns: [CheckIn], calendar: Calendar = .current) -> [CheckInPoint] {
        PhotoLogLogic.checkInsByDay(checkIns, calendar: calendar)
            .map { CheckInPoint(date: $0.key, pain: $0.value.pain) }
            .sorted { $0.date < $1.date }
    }

    // read out in place of the chart
    static func chartSummary(_ points: [CheckInPoint], now: Date, calendar: Calendar = .current) -> String {
        guard let last = points.last else { return chartEmpty }
        let when = PhotoLogLogic.shortDate(last.date, now: now, calendar: calendar)
        var text = "Pain over time. Latest \(last.pain) of 10 on \(when)."
        if points.count > 1 {
            let high = points.map(\.pain).max() ?? 0
            let low = points.map(\.pain).min() ?? 0
            text += " Highest \(high), lowest \(low), over \(points.count) check-ins."
        }
        return text
    }

}

// MARK: - Check-ins page (screen 45)

extension CheckInViewModel {
    static let pageTitle = "Check-Ins"
    static let painTitle = "Pain, 0 to 10"
    static let photosTitle = "Photos"
    static let notesTitle = "Notes"
    static let shareTitle = "Share"
    static let addPhotoTitle = "Add a Photo"
    static let checkInRowTitle = "Check In Now"

    // "Down from 6 on Monday to 4 today." from the first and last check-ins
    static func trendSentence(_ points: [CheckInPoint], now: Date, calendar: Calendar = .current) -> String {
        guard let first = points.first, let last = points.last else { return chartEmpty }
        let lastWhen = calendar.isDate(last.date, inSameDayAs: now) ? "today" : "on \(weekday(last.date))"
        guard points.count > 1 else { return "\(last.pain) \(lastWhen)." }
        let firstWhen = "on \(weekday(first.date))"
        if last.pain < first.pain { return "Down from \(first.pain) \(firstWhen) to \(last.pain) \(lastWhen)." }
        if last.pain > first.pain { return "Up from \(first.pain) \(firstWhen) to \(last.pain) \(lastWhen)." }
        return "Same as \(firstWhen): \(last.pain) \(lastWhen)."
    }

    private static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide))
    }

    // check-ins with words, newest first
    static func notes(_ checkIns: [CheckIn], plan: CarePlan?) -> [(id: String, title: String, text: String)] {
        guard let surgery = plan?.surgeryDate else { return [] }
        return checkIns.filter { !$0.note.isEmpty }
            .sorted { $0.day > $1.day }
            .map { ("\($0.day)", DayMath.shortDate(forDay: $0.day, from: surgery), "\u{201C}\($0.note)\u{201D}") }
    }
}
