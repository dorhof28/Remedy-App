//
//  MedicineMatcher.swift
//  Remedy
//
//  finds medicines in a sentence and says if theyre ok to take
//

import Foundation

// MARK: - Results

// a medicine found in a sentence, persistence names the saved kind MedicineMatch
struct MedicineMatchOf<Medicine: MedicineFacts>: Identifiable {
    var id: Medicine.LineID { medicine.lineID }
    let medicine: Medicine
    let matchedName: String
}

// can you take it
enum VerdictKind: Equatable {
    case dontTake       // a stop that's in effect now
    case stopSoon       // a stop that starts on a later day
    case stopEnded      // a stop whose end day has passed
    case okToTake       // "Tylenol is OK"
    case take           // take at set times, in effect now
    case asNeeded       // only when needed, in effect now
    case startsLater    // take / as-needed that starts on a later day
    case finished       // take / as-needed / OK whose end day has passed
}

// verdict with its wording
struct MedicineVerdict {
    let kind: VerdictKind
    let headline: String
    let sentence: String
}

// MARK: - The matcher

// finds which plan medicines a sentence or question names and what the papers say about each
enum MedicineMatcher {

    // finds medicines in a sentence - longest name wins
    static func matches<Medicine: MedicineFacts>(inSentence sentence: String, medicines: [Medicine],
                                                 today: Int) -> [MedicineMatchOf<Medicine>] {
        let text = sentence.lowercased()
        var found: [MedicineMatchOf<Medicine>] = []
        for medicine in medicines {
           
            let hits = names(of: medicine).filter { (name: String) -> Bool in text.contains(name) }
            let longest = hits.max { (first: String, second: String) -> Bool in first.count < second.count }
            if let longest = longest {
                found.append(MedicineMatchOf(medicine: medicine, matchedName: longest))
            }
        }
        
        let allNames = found.map { (match: MedicineMatchOf<Medicine>) -> String in match.matchedName }
        let exact = found.filter { (match: MedicineMatchOf<Medicine>) -> Bool in
            !allNames.contains { (other: String) -> Bool in
                other != match.matchedName && other.contains(match.matchedName)
            }
        }
        return ranked(exact, today: today)
    }

    // serach preview
    static func matches<Medicine: MedicineFacts>(forSearch query: String, medicines: [Medicine],
                                                 today: Int) -> [MedicineMatchOf<Medicine>] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard typed.count >= 2 else { return [] }
        var found: [MedicineMatchOf<Medicine>] = []
        for medicine in medicines {
            let hit = names(of: medicine).first { (name: String) -> Bool in
                name.hasPrefix(typed) || (typed.count >= 3 && name.contains(typed)) || typed.contains(name)
            }
            if let hit = hit {
                found.append(MedicineMatchOf(medicine: medicine, matchedName: hit))
            }
        }
        return ranked(found, today: today)
    }

    // rnak by best
    static func ranked<Medicine: MedicineFacts>(_ matches: [MedicineMatchOf<Medicine>], today: Int) -> [MedicineMatchOf<Medicine>] {
        matches.sorted { (first: MedicineMatchOf<Medicine>, second: MedicineMatchOf<Medicine>) -> Bool in
            let a = score(first.medicine, today: today)
            let b = score(second.medicine, today: today)
            return a < b
        }
    }

    // order
    private static func score(_ medicine: some MedicineFacts, today: Int) -> Int {
        let actionOrder: Int
        switch medicine.action {
        case .stop: actionOrder = 0
        case .take: actionOrder = 1
        case .takeAsNeeded: actionOrder = 2
        case .okToTake: actionOrder = 3
        }
        if DoseSchedule.isActive(medicine, on: today) {
            return actionOrder
        }
        let start = medicine.startDay ?? Int.min
        if start > today {
            return 100 + (start - today)
        }
        return 1000
    }

    // the medicine's own name plus every other name all lower-case
    static func names(of medicine: some MedicineFacts) -> [String] {
        // lowercased in case the ai saved Advil
        [medicine.name.lowercased()] + medicine.alsoKnownAs.map { $0.lowercased() }
    }

    // output based off other functions goes to main
    static func verdict(for medicine: some MedicineFacts, today: Int, surgeryDate: Date) -> MedicineVerdict {
        let started = today >= (medicine.startDay ?? Int.min)
        let ended = today > (medicine.endDay ?? Int.max)

        switch medicine.action {
        case .stop:
            if ended {
                return stopEnded(medicine, surgeryDate: surgeryDate)
            }
            if started {
                return dontTake(medicine, today: today, surgeryDate: surgeryDate)
            }
            return stopSoon(medicine, today: today, surgeryDate: surgeryDate)

        case .okToTake:
            if ended {
                let last = dateText(medicine.endDay, surgeryDate)
                return MedicineVerdict(kind: .finished, headline: "No longer listed as OK",
                                   sentence: "Your papers said it was OK until \(last). Ask your care team before taking it now.")
            }
            var sentence = "Your papers say it’s OK"
            if !medicine.onlyIf.isEmpty {
                sentence += " if \(PlainText.lowerFirst(medicine.onlyIf))"
            }
            sentence += "."
            if let end = medicine.endDay {
                sentence += " Until \(DayMath.shortDate(forDay: end, from: surgeryDate)) (\(DayMath.surgeryWords(forDay: end)))."
            }
            return MedicineVerdict(kind: .okToTake, headline: "OK to take", sentence: sentence)

        case .take, .takeAsNeeded:
            if ended {
                return MedicineVerdict(kind: .finished, headline: "Finished",
                                   sentence: "Your last day was \(dateText(medicine.endDay, surgeryDate)).")
            }
            if !started {
                let start = medicine.startDay ?? today
                return MedicineVerdict(kind: .startsLater,
                                   headline: "Starts \(DayMath.shortDate(forDay: start, from: surgeryDate))",
                                   sentence: "Start \(DayMath.surgeryWords(forDay: start)), on \(DayMath.longDate(forDay: start, from: surgeryDate)).")
            }
            if medicine.action == .take {
                return takeNow(medicine, surgeryDate: surgeryDate)
            }
            return asNeededNow(medicine, surgeryDate: surgeryDate)
        }
    }

    // split all the output from before into helper functions
    private static func dontTake(_ medicine: some MedicineFacts, today: Int, surgeryDate: Date) -> MedicineVerdict {
        var sentence: String
        if let start = medicine.startDay, start == today {
            sentence = "Stop today."
        } else if let start = medicine.startDay {
            sentence = "Stopped since \(DayMath.shortDate(forDay: start, from: surgeryDate))."
        } else {
            sentence = "Your papers say not to take it."
        }
        if let end = medicine.endDay {
            sentence += " Don’t take it until after \(DayMath.shortDate(forDay: end, from: surgeryDate))."
        } else {
            sentence += " Don’t take it until your surgeon says it’s OK."
        }
        return MedicineVerdict(kind: .dontTake, headline: "Don’t take", sentence: sentence)
    }

    // a stop that starts later
    private static func stopSoon(_ medicine: some MedicineFacts, today: Int, surgeryDate: Date) -> MedicineVerdict {
        let start = medicine.startDay ?? today
        let short = DayMath.shortDate(forDay: start, from: surgeryDate)
        let sentence = "Your papers say to stop it \(DayMath.surgeryWords(forDay: start)): \(DayMath.longDate(forDay: start, from: surgeryDate)), \(DayMath.relative(daysFromToday: start - today))."
        return MedicineVerdict(kind: .stopSoon, headline: "Stop on \(short)", sentence: sentence)
    }

    // a stop whose end day has passed
    private static func stopEnded(_ medicine: some MedicineFacts, surgeryDate: Date) -> MedicineVerdict {
        let last = dateText(medicine.endDay, surgeryDate)
        return MedicineVerdict(kind: .stopEnded, headline: "Stop has ended",
                           sentence: "Your papers said not to take it until \(last). Check with your surgeon before you start again.")
    }

    // a medicine to take on a schedule
    private static func takeNow(_ medicine: some MedicineFacts, surgeryDate: Date) -> MedicineVerdict {
        let times = medicine.timesOfDay.map { (minute: Int) -> String in DayMath.shortTimeText(minute) }
        var sentence = medicine.amount.isEmpty ? "Take it" : "Take \(medicine.amount)"
        if !times.isEmpty {
            sentence += " at \(PlainText.list(times))"
        }
        sentence += "."
        if !medicine.foodNote.isEmpty {
            sentence += " \(medicine.foodNote)."
        }
        if let end = medicine.endDay {
            sentence += " Last day: \(DayMath.shortDate(forDay: end, from: surgeryDate))."
        }
        return MedicineVerdict(kind: .take, headline: "Take every day", sentence: sentence)
    }

    // an as needed medicine, with what it is for and the gap
    private static func asNeededNow(_ medicine: some MedicineFacts, surgeryDate: Date) -> MedicineVerdict {
        var parts: [String] = []
        if !medicine.onlyIf.isEmpty {
            parts.append("Only for \(PlainText.lowerFirst(medicine.onlyIf)).")
        }
        if let hours = medicine.minHoursBetween {
            parts.append("Wait at least \(hours) hours between doses.")
        }
        if let max = medicine.maxPerDay {
            parts.append("No more than \(max) a day.")
        }
        if let end = medicine.endDay {
            parts.append("Last day: \(DayMath.shortDate(forDay: end, from: surgeryDate)).")
        }
        return MedicineVerdict(kind: .asNeeded, headline: "Only when needed", sentence: parts.joined(separator: " "))
    }

    
    private static func dateText(_ day: Int?, _ surgeryDate: Date) -> String {
        guard let day = day else { return "the end date" }
        return DayMath.shortDate(forDay: day, from: surgeryDate)
    }
}
