//
//  AIPlanConverter.swift
//  Remedy
//
//  turns ai answers into a draft plan and checks them
//

import Foundation
import os

// turns the model's answer into our DraftPlan checking every item against the pages first
enum AIPlanConverter {

    // the line with the date must talk about the surgery and not a visit
    // stops the visit date at the top of the papers becoming the surgery date
    static func isSurgeryLine(for date: String, in pages: [String]) -> Bool {
        let surgeryWords = ["surgery", "operation", "procedure", "surgical", "operative"]
        let visitWords = ["visit", "consult", "appointment", "seen", "printed", "encounter",
                          "testing", "evaluation", "clinic", "office", "after visit summary",
                          "pre-op", "preop", "pre op", "pre-surgery", "presurgery", "before surgery",
                          "preoperative", "pre-operative", "instructions", "date of service", "follow"]
        let lines = pages.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.lowercased() }
            .filter { $0.contains(date.lowercased()) }
        return lines.contains { line in
            surgeryWords.contains { line.contains($0) } && !visitWords.contains { line.contains($0) }
        }
    }

    // every ai answer into one checked draft
    static func draft(from plans: [AIPlan], pages: [String], paper: PaperKind) -> DraftPlan {
        let source = SourceMatcher(text: pages.joined(separator: "\n"))
        var draft = DraftPlan(paper: paper)
        var thrownOut = 0

        draft.procedure = plans.map(\.procedure).first { !$0.isEmpty } ?? ""     // just a label, the patient sees it
        // a labelled date beats the ai and the ai's date can't be a visit day
        let visitDays = plans.flatMap(\.visits).compactMap { ExplicitDateParser.parse(date: $0.dateText) }
        let labelled = SurgeryDateFinder.find(in: pages)
        let aiDate = plans.map(\.surgeryDate)
            .filter { source.contains($0) && isSurgeryLine(for: $0, in: pages) }
            .compactMap { ExplicitDateParser.parse(date: $0) }
            .first { !visitDays.contains($0) }
        // two different dates like a typed date and a handwritten moved to
        // so the patient picks instead of us guessing
        if let labelled, let aiDate, labelled != aiDate {
            draft.warnings.append("Your papers show two surgery dates, \(DayMath.shortDate(labelled)) and \(DayMath.shortDate(aiDate)). Pick the right one at the end.")
        } else {
            draft.surgeryDate = labelled ?? aiDate
        }
        draft.pages = pages.enumerated().map { DraftPage(pageNumber: $0.offset + 1, redactedText: $0.element) }

        for plan in plans {
            for m in plan.medicines {
                if let medicine = medicine(m, source: source, pages: pages) {
                    draft.medicines.append(medicine)
                } else { thrownOut += 1 }
            }
            for r in plan.rules {
                guard !r.title.isEmpty, isOnPage(r.quote, source) else { thrownOut += 1; continue }
                let evidence = r.quote + " " + r.whenText + " " + context(of: r.quote, in: source.text).joined(separator: " ")
                draft.rules.append(DraftRule(title: r.title, isAllowed: r.isAllowed, condition: r.condition,
                                             startDay: checked(r.startDay, in: evidence),
                                             endDay: checked(r.endDay, in: evidence),
                                             quote: r.quote, quotePage: page(of: r.quote, in: pages)))
            }
            for t in plan.tasks {
                guard !t.title.isEmpty, isOnPage(t.quote, source) else { thrownOut += 1; continue }
                draft.tasks.append(DraftTask(title: t.title, dueDay: checked(t.dueDay, in: t.quote),
                                             quote: t.quote, quotePage: page(of: t.quote, in: pages)))
            }
            for v in plan.visits {
                guard !v.title.isEmpty, isOnPage(v.quote, source) else { thrownOut += 1; continue }
                addVisit(v, to: &draft, source: source, pages: pages)
            }
            for c in plan.contacts {
                let phone = digits(c.phone)
                guard phone.count >= 7, digits(source.text).contains(phone) else { continue }   // number really on the page
                draft.contacts.append(DraftContact(name: c.name, detail: c.detail, phone: phone,
                                                   role: c.isPharmacy ? .pharmacy : .careTeam))
            }
        }

        if thrownOut > 0 {
            draft.warnings.append("We left out \(PlainText.count(thrownOut, "item")) the AI found that we couldn\u{2019}t find on your papers.")
            PlanReaders.log.info("Threw out \(thrownOut) items not on the papers")
        }
        return draft
    }

    // MARK: - Pieces

    private static func medicine(_ m: AIMedicine, source: SourceMatcher, pages: [String]) -> DraftMedicine? {
        let raw = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = m.isGroup ? CleanMedicineName(name: raw, strength: "", otherNames: []) : MedicineNameCleaner.clean(raw)
        let name = cleaned.name
        let strength = m.strength.isEmpty ? cleaned.strength : m.strength
        let quoteFound = isOnPage(m.quote, source)
        guard !name.isEmpty, quoteFound || source.contains(name) || source.contains(raw) else { return nil }   // made up

        // what we check numbers against the quote the when words and the lines above the name
        let quote = quoteFound ? m.quote : (source.firstLine(containing: name) ?? m.quote)
        let nameOnPage = source.contains(raw) ? raw : name
        let evidence = [quote, m.whenText, context(of: nameOnPage, in: source.text).joined(separator: " ")].joined(separator: " ")

        // stop days come from the words not the ai's number
        // so a list under 7 days before surgery gets -7 even when the ai left it empty
        let writtenDay = source.contains(m.whenText) ? DayPhraseParser.day(in: m.whenText) : nil
        // a heading only counts for before surgery days so a far off follow up line isnt used
        let stopDay = writtenDay ?? headingDay(of: nameOnPage, in: source.text).flatMap { $0 <= 0 ? $0 : nil }

        let action: MedicineAction
        switch m.action {
        case .take: action = .take
        case .takeAsNeeded: action = .takeAsNeeded
        case .stop: action = .stop
        case .okToTake: action = .okToTake
        }
        // other names in lower case no repeats same order
        var names: [String] = []
        for other in (cleaned.otherNames + m.otherNames).map({ $0.lowercased() })
        where !other.isEmpty && other != name.lowercased() && !names.contains(other) {
            names.append(other)
        }
        return DraftMedicine(
            name: name, alsoKnownAs: names, isGroup: m.isGroup, action: action,
            startDay: action == .stop ? (stopDay ?? checked(m.startDay, in: evidence)) : checked(m.startDay, in: evidence),
            endDay: checked(m.endDay, in: evidence),
            strength: source.containsIgnoringSpaces(strength) ? strength : "",
            amount: source.containsIgnoringSpaces(m.amount) ? m.amount : "",
            timesOfDay: action == .take ? doseTimes(m) : [],
            foodNote: m.foodNote, onlyIf: m.onlyIf,
            minHoursBetween: action == .takeAsNeeded ? m.everyHours : nil,
            maxPerDay: m.maxPerDay, reason: m.reason, exception: m.exception,
            quote: quote, quotePage: page(of: quote, in: pages) ?? page(of: nameOnPage, in: pages))
    }

    // a visit with a full written date becomes a visit
    private static func addVisit(_ v: AIVisit, to draft: inout DraftPlan, source: SourceMatcher, pages: [String]) {
        let quotePage = page(of: v.quote, in: pages)
        let hasTime = !v.timeText.isEmpty && source.contains(v.timeText)
        let written = source.contains(v.dateText)
            ? ExplicitDateParser.parse(date: v.dateText, time: hasTime ? v.timeText : nil)
            : nil

        if var when = written {
            var purpose = v.purpose
            if !hasTime {
                // calendars need a time use 9 AM and say so
                when = Calendar.current.date(byAdding: .hour, value: 9, to: when) ?? when
                purpose += (purpose.isEmpty ? "" : " ") + "The time isn\u{2019}t on your papers, so check it with the office."
            }
            let phone = digits(v.phone)
            draft.appointments.append(DraftAppointment(title: v.title, date: when, doctor: v.doctor, place: v.place,
                                                       phone: digits(source.text).contains(phone) ? phone : "",
                                                       purpose: purpose, quote: v.quote, quotePage: quotePage))
        } else {
            var title = "Call to book: \(v.title)"
            if let day = checked(v.dayFromSurgery, in: v.quote) { title += " (\(DayMath.surgeryWords(forDay: day)))" }
            draft.tasks.append(DraftTask(title: title, dueDay: nil, quote: v.quote, quotePage: quotePage))
        }
    }

    // minutes after midnight for an every-day medicine
    static func doseTimes(_ m: AIMedicine) -> [Int] {
        doseTimes(clockTimes: m.clockTimes, timesPerDay: m.timesPerDay, everyHours: m.everyHours)
    }

    // same rules from plain values
    static func doseTimes(clockTimes: [String], timesPerDay: Int?, everyHours: Int?) -> [Int] {
        let printed = clockTimes.compactMap { minute(of: $0) }
        if !printed.isEmpty { return printed.sorted() }
        if let hours = everyHours, hours > 0 {
            if hours >= 24 { return [480] }
            return Array(stride(from: 360, to: 1440, by: hours * 60))
        }
        switch timesPerDay {
        case 1: return [480]
        case 2: return [480, 1200]
        case 3: return [480, 840, 1200]
        case 4: return [480, 720, 960, 1200]
        default: return []
        }
    }

    // MARK: - Small helpers

    // the quote is on the page whole or in pieces like a heading then its list item
    static func isOnPage(_ quote: String, _ source: SourceMatcher) -> Bool {
        if source.contains(quote) { return true }
        let parts = quote.components(separatedBy: CharacterSet(charactersIn: ":;\n\u{2022}"))
            .filter { SourceMatcher.normalize($0).count >= 3 }
        return parts.count > 1 && parts.allSatisfy { source.contains($0) }
    }

    // the line with this text and the lines above it so a list heading counts
    static func context(of fragment: String, in text: String, above: Int = 12) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        let needle = SourceMatcher.normalize(fragment)
        guard !needle.isEmpty, let index = lines.firstIndex(where: { SourceMatcher.normalize($0).contains(needle) }) else { return [] }
        return Array(lines[max(0, index - above)...index])
    }

    // the closest when words at or above the line like a 7 days before heading
    // stops at a new numbered item so 3 eliquis doesnt take the 4 days from item 2
    static func headingDay(of fragment: String, in text: String) -> Int? {
        for line in context(of: fragment, in: text).reversed() {
            if let day = DayPhraseParser.day(in: line) { return day }
            if line.range(of: "^\\s*\\d{1,2}[.)]\\s", options: .regularExpression) != nil { return nil }
        }
        return nil
    }

    // keeps a day number only if it's really written
    private static func checked(_ day: Int?, in text: String) -> Int? {
        guard let day, SourceCheck.isDayStated(day, in: text) else { return nil }
        return day
    }

    // 08:00 to minutes
    static func minute(of text: String) -> Int? {
        let parts = text.split(separator: ":").prefix(2).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }

    // which page a quote is on
    static func page(of quote: String, in pages: [String]) -> Int? {
        guard !SourceMatcher.normalize(quote).isEmpty else { return nil }
        return pages.firstIndex { SourceMatcher(text: $0).contains(quote) }.map { $0 + 1 }
    }

    private static func digits(_ text: String) -> String {
        text.filter(\.isNumber)
    }
}
