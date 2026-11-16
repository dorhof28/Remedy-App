//
//  PaperCheckViewModel.swift
//  Remedy
//
//  the red cards and blue notes for papers that disagree, both looks
//

import Foundation
import SwiftData

// what one paper says, with who wrote it and when
struct CardQuote: Identifiable {
    // the paper id
    let id: UUID
    let doctor: String
    let dateText: String
    var text: String
    // "surgeon", "heart doctor"
    var role: String = ""
    // the paper reminders follow until it is sorted out
    var isFollowed = false
    // 16 what this paper says in plain words, "Stop 3 days before surgery." then "Last dose Thu, Nov 5."
    var plainLead: String = ""
    var plainRest: String = ""

    // "Dr. Rao, surgeon · printed Nov 2"
    var byline: String {
        let who = role.isEmpty ? doctor : "\(doctor), \(role)"
        return dateText == "no date" ? "\(who) \u{00B7} no date" : "\(who) \u{00B7} printed \(dateText)"
    }
}

// one call button on the sort it out sheet
struct CardCall: Identifiable, Equatable {
    let title: String       // "Call Dr. Rao"
    let url: URL
    var id: String { url.absoluteString }
}

// one finding ready to draw
struct PaperCheckCardData: Identifiable {
    let finding: Finding
    let message: CheckMessage
    let headline: String
    // newer paper first, one per paper
    let quotes: [CardQuote]
    let callTitle: String
    let phoneURL: URL?
    var email: String? = nil

    var id: String { finding.key }
    var isRed: Bool { message.color == .red }
    // the day to call by, nil means ask now
    var askByDate: Date?

    // the design's short lines, filled by the view model
    // "When to stop Apixaban?"
    var question: String = ""
    // "Ask by Friday." or "Ask today."
    var askByText: String = ""
    // "Until you hear back, Remedy follows Dr. Rao's paper."
    var followLine: String = ""
    // "Dr. Rao's paper", "" for a circle
    var followingPaper: String = ""
    // "last dose Friday"
    var followingMeaning: String = ""
    // "Dr. Lee's paper has no date, so Remedy can't tell which is newer."
    var noDateLine: String = ""
    // one per doctor with a number
    var calls: [CardCall] = []
    // the blue note: "Updated" then "by your newer paper from Dr. Rao (Thu, Nov 12)."
    var noteLead: String = ""
    var noteText: String = ""

    // the simple look phrases it as the thing to do: "Call about Apixaban"
    var simpleTitle: String { "Call about \(finding.medicine)" }

    // a circle or a paper with no date, the patient may know which to follow
    var asksPatientToChoose: Bool { finding.isCircle || finding.rule == .noPrintedDate }
    var resolveButton: String { asksPatientToChoose ? "Choose" : "They told me\u{2026}" }
    var resolveQuestion: String { asksPatientToChoose ? "Which paper should Remedy follow?" : "Which paper is right?" }

    // a calm note about a medicine the surgery papers don't mention, until the patient marks it asked
    var canMarkAsked: Bool { finding.rule == .notMentioned && !finding.isAsked }
    var markAskedTitle: String { "I asked the surgeon\u{2019}s office" }
    var symbol: String { finding.rule == .notMentioned ? "questionmark.circle" : "arrow.triangle.2.circlepath" }
}

// the paper check as cards: red to ask, blue to know, notes
struct PaperCheckViewModel {

    let plan: CarePlan?
    let now: Date

    private let report: PaperCheckReport?

    init(plan: CarePlan?, now: Date) {
        self.plan = plan
        self.now = now
        report = plan.map { PaperCheckReport.of($0) }
    }

    // MARK: - Words

    static let saveTitle = "Save"
    static let cancelTitle = "Cancel"
    static let blueSectionTitle = "Notes about your papers"
    static let disagreeTitle = "Your papers disagree"
    static let sortItOutTitle = "Sort it out"
    static let callTitle = "Call"
    static let sheetSubtitle = "Your papers say different things."
    static let followingBadge = "Following"
    static let doThisFirst = "Do this first"
    static let updatedWord = "Updated"
    static let seeBothTitle = "See both"
    static let whereFromTitle = "Where this came from"

    // several open disagreements share one card
    static func stackHeadline(count: Int) -> String {
        count == 1 ? disagreeTitle : "\(disagreeTitle) about \(count) medicines"
    }

    // MARK: - Cards

    // papers that still disagree, most urgent first, ones whose days are all past are left out
    var redCards: [PaperCheckCardData] { cards(from: report?.result.findings ?? []).filter { $0.isRed && !isOver($0) } }

    // newer papers that replaced older ones, what the office chose, and disagreements whose days are past
    var blueNotes: [PaperCheckCardData] { cards(from: report?.result.findings ?? []).filter { !$0.isRed || isOver($0) } }

    // how many things on the papers need the patient: open disagreements and medicines still to ask about
    var attentionCount: Int { Self.attentionCount(of: cards(from: report?.result.findings ?? []).filter { !isOver($0) }) }

    // a disagreement only about days already gone, nothing is left to ask
    private func isOver(_ card: PaperCheckCardData) -> Bool {
        guard card.isRed, let plan, let today = DoseSchedule.today(for: plan, now: now) else { return false }
        return card.finding.isOver(today: today)
    }

    // cards that still need the patient
    static func attentionCount(of cards: [PaperCheckCardData]) -> Int {
        cards.filter { $0.isRed || $0.canMarkAsked }.count
    }

    func redCards(for medicine: MedicineInstruction) -> [PaperCheckCardData] {
        cards(from: report?.findings(for: medicine) ?? []).filter { $0.isRed && !isOver($0) }
    }

    func blueNotes(for medicine: MedicineInstruction) -> [PaperCheckCardData] {
        cards(from: report?.findings(for: medicine) ?? []).filter { !$0.isRed }
    }

    private var surgeryDate: Date { plan?.surgeryDate ?? now }

    // one card per finding the wording has a message for
    private func cards(from findings: [Finding]) -> [PaperCheckCardData] {
        findings
            .compactMap { finding -> PaperCheckCardData? in
                guard let message = finding.message(surgeryDate: surgeryDate) else { return nil }
                // two lines from one paper show as one quote
                var quotes: [CardQuote] = []
                for (item, quote) in zip(finding.items, message.quotes) {
                    if let index = quotes.firstIndex(where: { $0.id == item.paperID }) {
                        quotes[index].text += " " + quote.text
                    } else {
                        quotes.append(CardQuote(id: item.paperID, doctor: quote.doctor,
                                                dateText: item.printedDate.map { DayMath.shortDate($0) } ?? "no date", text: quote.text))
                    }
                }
                let contact = contact(for: finding)
                let followed = finding.winnerPaperID ?? finding.defaultPaperID
                for index in quotes.indices {
                    let item = finding.items.first { $0.paperID == quotes[index].id }
                    quotes[index].role = item.map { Self.role($0) } ?? ""
                    quotes[index].isFollowed = quotes[index].id == followed
                    if let item {
                        quotes[index].plainLead = Self.plainLead(item)
                        quotes[index].plainRest = plainRest(item)
                    }
                }
                var card = PaperCheckCardData(
                    finding: finding, message: message,
                    headline: message.color == .red ? "\(message.headline) about \(finding.medicine)" : message.headline,
                    quotes: quotes, callTitle: contact.map { "Call \($0.name)" } ?? "",
                    phoneURL: contact.flatMap { DayMath.phoneURL($0.phone) },
                    email: contact.flatMap { ContactLinks.email(for: $0) },
                    askByDate: finding.askByDay.map { DayMath.date(forDay: $0, from: surgeryDate) })
                fillWords(&card, followed: followed)
                return card
            }
            // open red first
            .sorted { $0.isRed && !$1.isRed }
    }

    // the short lines of the banner, card and sheet
    private func fillWords(_ card: inout PaperCheckCardData, followed: UUID?) {
        let finding = card.finding
        let name = finding.medicine
        switch finding.kind {
        case .differentAction: card.question = "Take or stop \(name)?"
        case .differentStopDay: card.question = "When to stop \(name)?"
        case .differentDose: card.question = "How much \(name) to take?"
        default: card.question = "Which paper is right about \(name)?"
        }
        if let date = card.askByDate, date > now {
            let word = SimpleWording.dayWord(for: date, now: now)
            card.askByText = word == "today" ? "Ask today." : "Ask by \(word)."
        } else {
            card.askByText = "Ask today."
        }
        let item = finding.items.first { $0.paperID == followed }
        if finding.isCircle || item == nil {
            card.followLine = "Remedy isn\u{2019}t following any of these papers until you choose."
        } else if let item {
            let paper = Self.paperName(item)
            card.followingPaper = paper
            card.followingMeaning = meaning(of: item)
            let until = finding.rule == .noPrintedDate ? "Until you choose" : "Until you hear back"
            card.followLine = "\(until), Remedy follows \(paper)."
        }
        if let undated = finding.items.first(where: { $0.printedDate == nil }) {
            card.noDateLine = "\(SimpleWording.capitalized(Self.paperName(undated))) has no date, so Remedy can\u{2019}t tell which is newer."
        }
        card.calls = calls(for: finding, fallback: card)
        guard !card.isRed else { return }
        if finding.rule == .notMentioned {
            card.noteText = card.headline + "."
        } else if finding.isResolved {
            card.noteLead = "Sorted out"
            card.noteText = card.headline + "."
        } else {
            let newer = card.quotes.first
            let date = newer.map { $0.dateText == "no date" ? "" : " (\($0.dateText))" } ?? ""
            card.noteLead = PaperCheckViewModel.updatedWord
            card.noteText = "by your newer paper from \(newer?.doctor ?? "your care team")\(date)."
        }
    }

    // "Stop 3 days before surgery."
    static func plainLead(_ item: CheckItem) -> String {
        switch item.action {
        case .stop:
            guard let start = item.startDay else { return "Don\u{2019}t take it." }
            if start == 0 { return "Stop on surgery day." }
            let days = PlainText.count(abs(start), "day")
            return start < 0 ? "Stop \(days) before surgery." : "Stop \(days) after surgery."
        case .take: return "Keep taking it."
        case .takeAsNeeded: return "Take it if you need it."
        case .okToTake: return "It\u{2019}s allowed."
        }
    }

    // "Last dose Thu, Nov 5."
    private func plainRest(_ item: CheckItem) -> String {
        guard item.action == .stop, let start = item.startDay else { return "" }
        return "Last dose \(DayMath.shortDate(DayMath.date(forDay: start - 1, from: surgeryDate)))."
    }

    // what following that paper means in calendar words
    private func meaning(of item: CheckItem) -> String {
        switch item.action {
        case .stop:
            guard let start = item.startDay else { return "don\u{2019}t take it" }
            return "last dose \(SimpleWording.dayWord(for: DayMath.date(forDay: start - 1, from: surgeryDate), now: now))"
        case .take: return "keep taking it"
        case .takeAsNeeded: return "take it if you need it"
        case .okToTake: return "it\u{2019}s allowed"
        }
    }

    // a call button for each doctor whose office has a number, else the care team
    private func calls(for finding: Finding, fallback card: PaperCheckCardData) -> [CardCall] {
        let callable = (plan?.contacts ?? []).filter { $0.role == .careTeam && !$0.phone.isEmpty }
        var list: [CardCall] = []
        for item in finding.items {
            let doctor = (item.doctorName ?? "").lowercased()
            guard !doctor.isEmpty,
                  let match = callable.first(where: { "\($0.name) \($0.detail)".lowercased().contains(doctor) }),
                  let url = DayMath.phoneURL(match.phone), !list.contains(where: { $0.url == url }) else { continue }
            list.append(CardCall(title: "Call \(item.doctorName ?? match.name)", url: url))
        }
        if list.isEmpty, let url = card.phoneURL { list.append(CardCall(title: card.callTitle, url: url)) }
        return list
    }

    // "Dr. Rao's paper", "your surgeon's paper"
    static func paperName(_ item: CheckItem) -> String {
        if let name = item.doctorName?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return "\(name)\u{2019}s paper" }
        return "your \(role(item))\u{2019}s paper"
    }

    // "surgeon", "heart doctor"
    static func role(_ item: CheckItem) -> String {
        switch item.source {
        case .surgeryTeam: return "surgeon"
        case .primaryCare: return "family doctor"
        case .hospitalRecord: return "hospital record"
        case .other: return "doctor"
        case .specialist:
            switch item.field {
            case .heart: return "heart doctor"
            case .kidney: return "kidney doctor"
            case .blood: return "blood doctor"
            case .diabetes: return "diabetes doctor"
            case .lungs: return "lung doctor"
            case .other, .none: return "specialist"
            }
        }
    }

    // the office of the paper the app follows if a contact names it, else the first care team number
    private func contact(for finding: Finding) -> CareContact? {
        let callable = (plan?.contacts ?? []).filter { $0.role == .careTeam && !$0.phone.isEmpty }
        let followed = finding.winnerPaperID ?? finding.defaultPaperID
        let doctor = finding.items.first { $0.paperID == followed }?.doctorName?.lowercased() ?? ""
        if !doctor.isEmpty, let match = callable.first(where: { "\($0.name) \($0.detail)".lowercased().contains(doctor) }) {
            return match
        }
        return callable.first
    }

    // MARK: - Actions

    // the patient tells us which paper to follow, from the office or their own pick
    static func save(_ card: PaperCheckCardData, chosen: UUID, officeSaid: String, whoSaid: String,
                     now: Date = Date(), in context: ModelContext) {
        let trim = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines) }
        context.insert(PaperCheckNote(findingKey: card.finding.key, chosenPaperID: chosen,
                                      officeSaid: trim(officeSaid), whoSaid: trim(whoSaid), date: now))
        context.saveNow()
    }

    // the patient asked about a medicine the surgery papers don't mention, saved like an office answer
    static func markAsked(_ card: PaperCheckCardData, now: Date = Date(), in context: ModelContext) {
        guard card.canMarkAsked else { return }
        save(card, chosen: card.finding.newer.paperID, officeSaid: "", whoSaid: "", now: now, in: context)
    }
}
