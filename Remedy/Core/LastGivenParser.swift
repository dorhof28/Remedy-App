//
//  LastGivenParser.swift
//  Remedy
//
//  the hospital's last dose time copied word for word from the discharge paper
//  strict on purpose so a made up or unclear time gives nothing
//

import Foundation

// what the last given words give
nonisolated enum LastGivenReading: Equatable {
    case none                               // no clear time, the plan keeps its normal times
    case time(Date)
    case needsAmPm(am: Date, pm: Date)      // the patient picks, never guessed

    var time: Date? {
        if case .time(let date) = self { return date }
        return nil
    }
}

// reads when the hospital last gave a medicine, so the first dose at home waits the right gap
nonisolated enum LastGivenParser {

    // a time only when the words have one clear clock time and are really on the page
    // the day is the paper's printed day which is the discharge day
    // medicine names let a line naming the medicine settle a missing am pm
    static func time(from text: String, pageText: String, printedDate: Date?, medicineNames: [String] = []) -> Date? {
        reading(from: text, pageText: pageText, printedDate: printedDate, medicineNames: medicineNames).time
    }

    // same but a missing am pm the patient picked counts when it is one of the two choices
    static func time(from text: String, pageText: String, printedDate: Date?, medicineNames: [String], picked: Date?) -> Date? {
        switch reading(from: text, pageText: pageText, printedDate: printedDate, medicineNames: medicineNames) {
        case .time(let date): return date
        case .needsAmPm(let am, let pm): return picked.flatMap { $0 == am || $0 == pm ? $0 : nil }
        case .none: return nil
        }
    }

    // a clear time, a time that needs am or pm, or nothing
    static func reading(from text: String, pageText: String, printedDate: Date?, medicineNames: [String] = []) -> LastGivenReading {
        guard let printedDate, appears(text, in: pageText) else { return .none }
        let day = DayMath.calendar.startOfDay(for: printedDate)
        func at(_ minute: Int) -> Date? {
            DayMath.calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
        }
        if let minute = minute(in: text) { return at(minute).map { .time($0) } ?? .none }
        guard let morning = unclearMinute(in: text), let am = at(morning), let pm = at(morning + 12 * 60) else { return .none }
        let fromNames = halves(of: morning, onLinesNaming: medicineNames, in: pageText)
        let fromPrint = halvesBeforePrint(of: morning, in: pageText, printedDay: day)
        switch fromNames.intersection(fromPrint) {
        case [.am]: return .time(am)
        case [.pm]: return .time(pm)
        default: return .needsAmPm(am: am, pm: pm)
        }
    }

    // same for a row labelled last given
    static func hospitalText(_ date: Date) -> String {
        "In the hospital at \(DayMath.timeText(of: date)) (from your paper)"
    }

    // MARK: - Pieces

    // 1:40 PM 1:40pm 1:40 p.m. or 13:40
    private static let clock = try! NSRegularExpression(
        pattern: "(?<![0-9:])([0-9]{1,2}):([0-9]{2})(?:\\s*([AaPp])\\.?[Mm]\\.?)?(?![0-9A-Za-z])")

    // minutes after midnight of the one clock time in the text
    // nil for none two different ones or one without am pm that could be morning or evening
    static func minute(in text: String) -> Int? {
        let range = NSRange(text.startIndex..., in: text)
        var found: Set<Int> = []
        for match in clock.matches(in: text, range: range) {
            guard let minute = minute(of: match, in: text) else { return nil }
            found.insert(minute)
        }
        return found.count == 1 ? found.first : nil
    }

    // the minute of the day from a matched clock time
    private static func minute(of match: NSTextCheckingResult, in text: String) -> Int? {
        func part(_ index: Int) -> String? {
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
        guard let hourText = part(1), let hour = Int(hourText), let minutes = part(2).flatMap({ Int($0) }),
              (0..<60).contains(minutes) else { return nil }
        if let half = part(3)?.lowercased() {
            guard (1...12).contains(hour) else { return nil }
            let hour24 = hour % 12 + (half == "p" ? 12 : 0)
            return hour24 * 60 + minutes
        }
        // no am pm only counts when it can only be 24 hour like 13:40 or 08:15
        let clearly24 = hourText.count == 2 && (hour >= 13 || hourText.hasPrefix("0"))
        guard clearly24, hour < 24 else { return nil }
        return hour * 60 + minutes
    }

    // MARK: - Missing am pm

    // morning or afternoon for a time with no am or pm
    enum Half { case am, pm }

    // the morning minute of the one clock time when it has no am pm and could be either, like 1:40 or 12:15
    // nil when there is a clear time too or two different ones
    static func unclearMinute(in text: String) -> Int? {
        let range = NSRange(text.startIndex..., in: text)
        var found: Set<Int> = []
        for match in clock.matches(in: text, range: range) {
            guard match.range(at: 3).location == NSNotFound,
                  let hourRange = Range(match.range(at: 1), in: text), let minuteRange = Range(match.range(at: 2), in: text),
                  let hour = Int(text[hourRange]), let minutes = Int(text[minuteRange]),
                  (1...12).contains(hour), (0..<60).contains(minutes),
                  !(text[hourRange].count == 2 && text[hourRange].hasPrefix("0")) else { return nil }
            found.insert((hour % 12) * 60 + minutes)
        }
        return found.count == 1 ? found.first : nil
    }

    // am or pm the same clock time has on page lines naming the medicine, both when nothing says
    private static func halves(of morning: Int, onLinesNaming names: [String], in page: String) -> Set<Half> {
        var seen: Set<Half> = []
        for line in page.split(whereSeparator: \.isNewline).map(String.init)
        where names.contains(where: { !$0.isEmpty && mentions(line, name: $0) }) {
            for minute in clearMinutes(in: line) where minute % (12 * 60) == morning {
                seen.insert(minute < 12 * 60 ? .am : .pm)
            }
        }
        return seen.count == 1 ? seen : [.am, .pm]
    }

    // a dose given by the time the paper was printed, only from a printed line dated the discharge day
    private static func halvesBeforePrint(of morning: Int, in page: String, printedDay: Date) -> Set<Half> {
        for line in page.split(whereSeparator: \.isNewline).map(String.init) where line.lowercased().contains("printed") {
            guard let date = PaperClues.printedDate(in: [line]),
                  DayMath.calendar.isDate(date, inSameDayAs: printedDay),
                  let printed = minute(in: line) else { continue }
            var possible: Set<Half> = []
            if morning <= printed { possible.insert(.am) }
            if morning + 12 * 60 <= printed { possible.insert(.pm) }
            return possible.isEmpty ? [.am, .pm] : possible
        }
        return [.am, .pm]
    }

    // every clock time with am pm or clearly 24 hour in a line
    private static func clearMinutes(in line: String) -> [Int] {
        clock.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { minute(of: $0, in: line) }
    }

    // the medicine name as a whole word, case does not count
    private static func mentions(_ line: String, name: String) -> Bool {
        let pattern = "(?<![A-Za-z])" + NSRegularExpression.escapedPattern(for: name) + "(?![A-Za-z])"
        return line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // the same words on the page, line breaks and case don't count
    // and not just the end of a longer time like 1:40 inside 11:40
    static func appears(_ text: String, in page: String) -> Bool {
        let needle = squash(text)
        let haystack = squash(page)
        guard let first = needle.first, let last = needle.last else { return false }
        let isWord: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        var searchFrom = haystack.startIndex
        while let found = haystack.range(of: needle, options: .caseInsensitive, range: searchFrom..<haystack.endIndex) {
            let before = found.lowerBound == haystack.startIndex ? nil : haystack[haystack.index(before: found.lowerBound)]
            let after = found.upperBound == haystack.endIndex ? nil : haystack[found.upperBound]
            let cutStart = isWord(first) && before.map(isWord) == true
            let cutEnd = isWord(last) && after.map(isWord) == true
            if !cutStart && !cutEnd { return true }
            searchFrom = haystack.index(after: found.lowerBound)
        }
        return false
    }

    // one space between words
    private static func squash(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
