//
//  ScanFlowViewModel.swift
//  Remedy
//
//  welcome scan and confirm for both looks
//

import AuthenticationServices
import Foundation
import Observation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

// where we are in the flow
enum ScanStep: Equatable {
    case welcome
    case choosePaper
    case reading
    case confirm
    case finish
}

// the three things "reading" does shown as a checklist
enum ReadingStage: Int, CaseIterable, Identifiable {
    case readingWords
    case removingPersonalInfo
    case findingInstructions
    case done

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .readingWords: return "Reading the words on this phone"
        case .removingPersonalInfo: return "Removing your name and record numbers"
        case .findingInstructions: return "Finding medicines, rules and visits"
        case .done: return "Done"
        }
    }
}

// which kind of item a card is and where it sits in the draft
enum ConfirmItem: Equatable {
    case medicine(Int)
    case rule(Int)
    case task(Int)
    case appointment(Int)
}

// one page after redaction
struct CleanedPage: Identifiable {
    let number: Int
    let text: String
    let removedCount: Int

    var id: Int { number }
    var title: String { "Page \(number)" }
    var removedText: String {
        removedCount == 0 ? "Nothing personal found" : "\(PlainText.count(removedCount, "detail")) hidden"
    }
}

// one card on the Confirm screen
struct ConfirmCard: Identifiable {
    let id: UUID
    let item: ConfirmItem
    let eyebrow: String         // "Stop taking"
    let symbol: String
    let tone: Tone
    let title: String           // "Ibuprofen (Motrin, Advil)"
    let facts: [InfoRow]        // When / How much / Why ...
    let quote: String
    let quoteSource: String
}

// what the Edit sheet can change
struct ConfirmEdit {
    var title: String
    var hasStart: Bool
    var startDay: Int
    var hasEnd: Bool
    var endDay: Int
    var showsDays: Bool         // visits use their date instead
}

@Observable
final class ScanFlowViewModel {

    // MARK: - State

    var step: ScanStep
    var paper: PaperKind = .beforeSurgery
    var stage: ReadingStage = .readingWords
    var draft: DraftPlan?
    var cleanedText = ""            // first page after redaction (shown to the patient)
    var cleanedPages: [CleanedPage] = []   // every page after redaction for the full view
    var removedCount = 0
    var cardIndex = 0
    var removedIDs: Set<UUID> = []  // "Not on my papers"
    var surgeryDate: Date
    var errorText: String?
    var isImportingFromEpic = false
    var isImportingFromHealth = false
    var photoItems: [PhotosPickerItem] = []

    // true when adding papers to a plan that already exists
    let isAddingPapers: Bool
    private let planHasSurgeryDate: Bool

    init(isAddingPapers: Bool = false, planHasSurgeryDate: Bool = false, now: Date = AppClock.now()) {
        self.isAddingPapers = isAddingPapers
        self.planHasSurgeryDate = planHasSurgeryDate
        self.step = isAddingPapers ? .choosePaper : .welcome
        self.surgeryDate = now
        // after surgery is the usual second scan
        self.paper = isAddingPapers ? .afterSurgery : .beforeSurgery
    }

    // MARK: - Words

    let appName = "Remedy"
    let welcomeTitle = "Your surgery papers, made simple"
    let welcomeDetail = "Scan the papers from your surgeon. Remedy turns them into a day-by-day plan: what to stop, what to take, and when."
    let welcomeButton = "Scan my papers"
    let welcomePrivacy = "Your name and record numbers are removed on this phone before anything is read by AI."
    let choosePaperTitle = "Which papers?"
    let cameraButton = "Scan with camera"
    let photosButton = "Choose photos"
    let pdfButton = "Choose a PDF"
    let epicButton = "Import from MyChart"
    let epicSource = "From MyChart (Epic)"
    let healthButton = "Import from Apple Health"
    let healthSource = "From Apple Health Records"
    let sampleButton = "Use sample papers"
    let readingTitle = "Reading your papers"
    let cleanedTitle = "What the AI sees"
    let continueButton = "Check each item"
    let confirmTitle = "Check your plan"
    let confirmHint = "Make sure each item matches your papers."
    let looksRightButton = "Looks right"
    let editButton = "Edit"
    let removeButton = "Not on my papers"
    let backButton = "Back"
    let finishTitle = "Your plan is ready"
    let surgeryDateTitle = "When is your surgery?"
    // asks every time so a visit date on the papers never becomes the surgery date
    var surgeryDateDetail: String {
        if let found = draft?.surgeryDate {
            return "Your papers mention \(DayMath.longDate(found)). Make sure that\u{2019}s the day of the operation, not a visit."
        }
        return "Your papers count days from surgery (\u{201C}4 days before\u{201D}), so we need the date to give real dates."
    }
    let startButton = "Start my plan"
    let cancelButton = "Cancel"
    let noItemsText = "We couldn\u{2019}t find any instructions on these pages. Try scanning again in good light."

    // one line on the welcome screen
    struct Feature: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    let features = [
        Feature(id: "scan", symbol: "doc.text.viewfinder", title: "Scan your papers", detail: "Before-surgery and discharge papers"),
        Feature(id: "check", symbol: "checkmark.shield", title: "Check every line", detail: "Nothing is used until you say it\u{2019}s right"),
        Feature(id: "plan", symbol: "calendar", title: "Know what to do each day", detail: "Reminders, real dates, and answers from your papers"),
    ]

    // MARK: - Choose papers

    // before or after surgery papers
    struct PaperOption: Identifiable {
        let id: PaperKind
        let title: String
        let detail: String
        let symbol: String
    }

    let paperOptions = [
        PaperOption(id: .beforeSurgery, title: "Before surgery", detail: "What to stop and bring", symbol: "calendar.badge.clock"),
        PaperOption(id: .afterSurgery, title: "After surgery", detail: "Discharge papers from the hospital", symbol: "house"),
    ]

    var canUseCamera: Bool { DocumentScanner.isAvailable }

    // DEMO ONLY the sample-papers button shows in the demo schemes
    var showsSampleButton: Bool { LaunchOptions.isDemo }

    // "Scan my papers" on the welcome screen
    func begin() {
        withAnimation { step = .choosePaper }
    }

    // picks which papers
    func choose(_ paper: PaperKind) {
        self.paper = paper
    }

    // MARK: - Reading

    var stages: [ReadingStage] { [.readingWords, .removingPersonalInfo, .findingInstructions] }

    func isDone(_ stage: ReadingStage) -> Bool { stage.rawValue < self.stage.rawValue }
    func isRunning(_ stage: ReadingStage) -> Bool { stage == self.stage }
    var isReadingDone: Bool { stage == .done }

    var seeAllTitle: String {
        cleanedPages.count > 1 ? "See all \(cleanedPages.count) pages" : "See the whole page"
    }
    let sentPagesTitle = "What the AI sees"
    let sentPagesDetail = "This is exactly what was sent. Blacked out parts never left your phone."

    var removedText: String {
        removedCount == 0 ? "Nothing personal was found." : "Removed \(PlainText.count(removedCount, "personal detail")) on this phone."
    }

    // camera pages
    func process(images: [UIImage]) async {
        start()
        let pages = await TextReader.read(images)
        await process(pages: pages)
    }

    // photos picked from the library
    func processPhotos() async {
        start()
        var images: [UIImage] = []
        for item in photoItems {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        photoItems = []
        let pages = await TextReader.read(images)
        await process(pages: pages)
    }

    // a PDF from the Files app
    func processPDF(at url: URL) async {
        start()
        do {
            let pages = try await PDFReader.read(url)
            await process(pages: pages)
        } catch {
            errorText = (error as? PDFReaderError)?.errorDescription ?? "We couldn\u{2019}t open that PDF."
            withAnimation { step = .choosePaper }
        }
    }

    // MARK: - MyChart (Epic)

    // shows once Services/Epic/EpicConfig has a client ID
    var showsEpicButton: Bool { EpicConfig.isSetUp }

    // mychart import then the confirm screen
    func importFromEpic(using webAuth: WebAuthenticationSession) async {
        errorText = nil
        isImportingFromEpic = true
        defer { isImportingFromEpic = false }
        do {
            draft = try await EpicImporter.importPlan(paper: paper, using: webAuth)
            cardIndex = 0
            removedIDs = []
            goToConfirm()
        } catch EpicError.cancelled {
            // the patient closed the sign-in just stay here
        } catch {
            errorText = (error as? EpicError)?.errorDescription
                ?? "We couldn\u{2019}t reach your hospital. Check your internet, or scan your papers instead."
        }
    }

    // MARK: - Apple Health Records

    // only on iPhones that can hold Health Records
    var showsHealthButton: Bool { HealthService.canReadRecords }

    // apple health import then the confirm screen
    func importFromHealth() async {
        errorText = nil
        isImportingFromHealth = true
        defer { isImportingFromHealth = false }
        do {
            draft = try await HealthRecordsImporter.importPlan(paper: paper)
            cardIndex = 0
            removedIDs = []
            goToConfirm()
        } catch {
            errorText = (error as? HealthImportError)?.errorDescription
                ?? "We couldn\u{2019}t read your Health Records. You can scan your papers instead."
        }
    }

    // things to double-check from this read
    var warnings: [String] { draft?.warnings ?? [] }

    // read by google gemini
    var readByText: String {
        guard let name = draft?.readBy, !name.isEmpty else { return "" }
        return "Read by \(name)"
    }

    // DEMO ONLY skips the camera and uses the sample page text
    func useSamplePapers() async {
        start()
        try? await Task.sleep(for: .seconds(1))
        await process(pages: [SampleDrafts.pageText(for: paper)])
    }

    private func start() {
        errorText = nil
        stage = .readingWords
        withAnimation { step = .reading }
    }

    // redact on the phone then ask the AI for a draft
    private func process(pages: [String]) async {
        // no words at all
        guard pages.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorText = PlanReaderError.couldNotRead.errorDescription
            withAnimation { step = .choosePaper }
            return
        }
        withAnimation { stage = .removingPersonalInfo }
        let redacted = await AIRedactor.redact(pages)     // rules + Apple's phone AI, never the cloud
        cleanedText = redacted.first?.text ?? ""
        cleanedPages = redacted.enumerated().map { index, page in
            CleanedPage(number: index + 1, text: page.text, removedCount: page.removedCount)
        }
        removedCount = redacted.reduce(0) { $0 + $1.removedCount }
        try? await Task.sleep(for: .seconds(1))     // long enough to see the step

        withAnimation { stage = .findingInstructions }
        do {
            draft = try await PlanReaders.current.readPlan(from: redacted.map(\.text), paper: paper)
            cardIndex = 0
            removedIDs = []
            withAnimation { stage = .done }
        } catch {
            // our own errors have patient-friendly words
            errorText = (error as? PlanReaderError)?.errorDescription
                ?? "Something went wrong reading your papers. Check your internet and try again."
            withAnimation { step = .choosePaper }
        }
    }

    // starts checking items
    func goToConfirm() {
        // start the date picker on the date the papers gave so its one tap to confirm
        if let found = draft?.surgeryDate { surgeryDate = found }
        withAnimation { step = cards.isEmpty ? .finish : .confirm }
    }

    // MARK: - Confirm

    // every item that needs a yes in the order they appear on the paper
    var cards: [ConfirmCard] {
        guard let draft else { return [] }
        var result: [ConfirmCard] = []
        for (index, medicine) in draft.medicines.enumerated() { result.append(card(for: medicine, index: index)) }
        for (index, rule) in draft.rules.enumerated() { result.append(card(for: rule, index: index)) }
        for (index, task) in draft.tasks.enumerated() { result.append(card(for: task, index: index)) }
        for (index, visit) in draft.appointments.enumerated() { result.append(card(for: visit, index: index)) }
        return result
    }

    var currentCard: ConfirmCard? {
        let all = cards
        return all.indices.contains(cardIndex) ? all[cardIndex] : nil
    }

    var progressText: String { "\(min(cardIndex + 1, cards.count)) of \(cards.count)" }
    var progressTotal: Int { cards.count }
    var canGoBack: Bool { cardIndex > 0 }

    // item matches the paper
    func looksRight() {
        guard let card = currentCard else { return }
        setConfirmed(card.item, true)
        removedIDs.remove(card.id)
        next()
    }

    // item is wrong so drop it
    func notOnPapers() {
        guard let card = currentCard else { return }
        setConfirmed(card.item, false)
        removedIDs.insert(card.id)
        next()
    }

    // previous item
    func back() {
        guard canGoBack else { return }
        withAnimation { cardIndex -= 1 }
    }

    private func next() {
        withAnimation {
            if cardIndex + 1 < cards.count {
                cardIndex += 1
            } else {
                step = .finish
            }
        }
    }

    // MARK: - Edit

    // current item for the edit sheet
    func editValues() -> ConfirmEdit? {
        guard let draft, let card = currentCard else { return nil }
        switch card.item {
        case .medicine(let i):
            let m = draft.medicines[i]
            return ConfirmEdit(title: m.name, hasStart: m.startDay != nil, startDay: m.startDay ?? 0,
                               hasEnd: m.endDay != nil, endDay: m.endDay ?? 0, showsDays: true)
        case .rule(let i):
            let r = draft.rules[i]
            return ConfirmEdit(title: r.title, hasStart: r.startDay != nil, startDay: r.startDay ?? 0,
                               hasEnd: r.endDay != nil, endDay: r.endDay ?? 0, showsDays: true)
        case .task(let i):
            let t = draft.tasks[i]
            return ConfirmEdit(title: t.title, hasStart: t.dueDay != nil, startDay: t.dueDay ?? 0,
                               hasEnd: false, endDay: 0, showsDays: true)
        case .appointment(let i):
            return ConfirmEdit(title: draft.appointments[i].title, hasStart: false, startDay: 0,
                               hasEnd: false, endDay: 0, showsDays: false)
        }
    }

    // saves the edit and counts it as confirmed
    func saveEdit(_ edit: ConfirmEdit) {
        guard draft != nil, let card = currentCard else { return }
        let title = edit.title.trimmingCharacters(in: .whitespaces)
        let start = edit.hasStart ? edit.startDay : nil
        let end = edit.hasEnd ? edit.endDay : nil
        switch card.item {
        case .medicine(let i):
            if !title.isEmpty { draft?.medicines[i].name = title }
            draft?.medicines[i].startDay = start
            draft?.medicines[i].endDay = end
        case .rule(let i):
            if !title.isEmpty { draft?.rules[i].title = title }
            draft?.rules[i].startDay = start
            draft?.rules[i].endDay = end
        case .task(let i):
            if !title.isEmpty { draft?.tasks[i].title = title }
            draft?.tasks[i].dueDay = start
        case .appointment(let i):
            if !title.isEmpty { draft?.appointments[i].title = title }
        }
        looksRight()
    }

    // "3 days before surgery" under the day steppers
    func dayWords(_ day: Int) -> String {
        upperFirst(DayMath.surgeryWords(forDay: day))
    }

    // MARK: - Finish

    var confirmedCount: Int { cards.count - removedIDs.count }
    var finishDetail: String {
        var text = "You checked \(PlainText.count(confirmedCount, "item"))."
        if !removedIDs.isEmpty {
            text += " \(PlainText.count(removedIDs.count, "item")) left out."
        }
        return text
    }

    var needsSurgeryDate: Bool { !planHasSurgeryDate }

    // saves only the confirmed items
    func save(in context: ModelContext) {
        guard var draft else { return }
        if needsSurgeryDate {
            draft.surgeryDate = surgeryDate
        }
        PlanImporter.save(draft, in: context)
    }

    // MARK: - Cards (private)

    private func card(for m: DraftMedicine, index: Int) -> ConfirmCard {
        let eyebrow: String
        let symbol: String
        let tone: Tone
        switch m.action {
        case .stop: eyebrow = "Stop taking"; symbol = "nosign"; tone = .stop
        case .take: eyebrow = "Take every day"; symbol = "pills.fill"; tone = .info
        case .takeAsNeeded: eyebrow = "Only when needed"; symbol = "clock"; tone = .info
        case .okToTake: eyebrow = "OK to take"; symbol = "checkmark.circle.fill"; tone = .good
        }
        var title = m.name
        let otherNames = m.alsoKnownAs.filter { $0 != m.name.lowercased() }.prefix(2).map { self.upperFirst($0) }
        if !otherNames.isEmpty && !m.isGroup { title += " (\(otherNames.joined(separator: ", ")))" }

        var facts = [InfoRow(id: "when", label: "When", value: whenText(m.startDay, m.endDay))]
        let howMuch = [m.amount, m.strength.isEmpty ? "" : "of \(m.strength)"].filter { !$0.isEmpty }.joined(separator: " ")
        if !howMuch.isEmpty { facts.append(InfoRow(id: "amount", label: "How much", value: howMuch)) }
        if !m.timesOfDay.isEmpty {
            facts.append(InfoRow(id: "times", label: "Times", value: PlainText.list(m.timesOfDay.sorted().map { DayMath.shortTimeText($0) })))
        }
        if !m.onlyIf.isEmpty { facts.append(InfoRow(id: "onlyif", label: "Only if", value: m.onlyIf)) }
        if let hours = m.minHoursBetween { facts.append(InfoRow(id: "gap", label: "Wait", value: "\(hours) hours between doses")) }
        if let max = m.maxPerDay { facts.append(InfoRow(id: "max", label: "Most a day", value: "\(max)")) }
        if m.isGroup && !m.alsoKnownAs.isEmpty {
            facts.append(InfoRow(id: "includes", label: "Includes", value: m.alsoKnownAs.prefix(6).map { self.upperFirst($0) }.joined(separator: ", ")))
        }
        if !m.reason.isEmpty { facts.append(InfoRow(id: "why", label: "Why", value: m.reason)) }
        if !m.exception.isEmpty { facts.append(InfoRow(id: "except", label: "Except", value: m.exception)) }

        return ConfirmCard(id: m.id, item: .medicine(index), eyebrow: eyebrow, symbol: symbol, tone: tone, title: title,
                           facts: facts, quote: m.quote, quoteSource: sourceText(page: m.quotePage))
    }

    private func card(for r: DraftRule, index: Int) -> ConfirmCard {
        var facts = [InfoRow(id: "when", label: "When", value: whenText(r.startDay, r.endDay))]
        if !r.condition.isEmpty { facts.append(InfoRow(id: "while", label: "Only while", value: r.condition)) }
        return ConfirmCard(id: r.id, item: .rule(index),
                           eyebrow: r.isAllowed ? "You may" : "Don\u{2019}t",
                           symbol: r.isAllowed ? "checkmark.circle.fill" : "hand.raised.fill",
                           tone: r.isAllowed ? .good : .stop, title: r.title, facts: facts,
                           quote: r.quote, quoteSource: sourceText(page: r.quotePage))
    }

    private func card(for t: DraftTask, index: Int) -> ConfirmCard {
        let due = t.dueDay.map { upperFirst(DayMath.surgeryWords(forDay: $0)) } ?? "No date on the papers"
        return ConfirmCard(id: t.id, item: .task(index), eyebrow: "To do", symbol: "checklist", tone: .caution,
                           title: t.title, facts: [InfoRow(id: "due", label: "By", value: due)],
                           quote: t.quote, quoteSource: sourceText(page: t.quotePage))
    }

    private func card(for a: DraftAppointment, index: Int) -> ConfirmCard {
        var facts = [InfoRow(id: "when", label: "When", value: "\(DayMath.longDate(a.date)), \(DayMath.timeText(of: a.date))")]
        if !a.place.isEmpty { facts.append(InfoRow(id: "where", label: "Where", value: a.place)) }
        if !a.doctor.isEmpty { facts.append(InfoRow(id: "who", label: "With", value: a.doctor)) }
        return ConfirmCard(id: a.id, item: .appointment(index), eyebrow: "Visit", symbol: "stethoscope", tone: .info,
                           title: a.title, facts: facts,
                           quote: a.quote, quoteSource: sourceText(page: a.quotePage))
    }

    // which days a rule or medicine covers
    private func whenText(_ start: Int?, _ end: Int?) -> String {
        switch (start, end) {
        case let (start?, end?):
            return "\(upperFirst(DayMath.surgeryWords(forDay: start))) to \(DayMath.surgeryWords(forDay: end))"
        case let (start?, nil):
            return "From \(DayMath.surgeryWords(forDay: start))"
        case let (nil, end?):
            return "Until \(DayMath.surgeryWords(forDay: end))"
        case (nil, nil):
            return paper == .afterSurgery ? "From surgery day" : "Starting now"
        }
    }

    // "After-surgery papers page 1" or where an import came from
    private func sourceText(page: Int?) -> String {
        switch draft?.source {
        case .epic: return epicSource
        case .appleHealth: return healthSource
        default: return PlainText.source(paper: paper, page: page)
        }
    }

    private func setConfirmed(_ item: ConfirmItem, _ value: Bool) {
        switch item {
        case .medicine(let i): draft?.medicines[i].isConfirmed = value
        case .rule(let i): draft?.rules[i].isConfirmed = value
        case .task(let i): draft?.tasks[i].isConfirmed = value
        case .appointment(let i): draft?.appointments[i].isConfirmed = value
        }
    }

    private func upperFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
