//
//  ReadAgreement.swift
//  Remedy
//
//  compares two reads of the same page and finds lines where the numbers differ
//  a dose that reads 5 one time and 50 the next is never trusted silently
//

import Foundation

// compares the camera read with the page model read and lists numbers they disagree on
nonisolated enum ReadAgreement {

    // one line both reads saw with different numbers
    struct Mismatch: Equatable, Sendable {
        let line: String
        let other: String
    }

    // lines of the kept read whose numbers differ from the matching line of the other read
    // a line only matches when most of its words are the same, so moved or missing lines are skipped
    static func numberMismatches(kept: [String], other: [String]) -> [Mismatch] {
        let others = other.map { (text: $0, words: words($0), numbers: numbers($0)) }
        var found: [Mismatch] = []
        for line in kept where matters(line) {
            let mine = numbers(line)
            let lineWords = words(line)
            guard !mine.isEmpty, !lineWords.isEmpty else { continue }
            let close = others.filter { overlap(lineWords, $0.words) >= 0.6 && !$0.numbers.isEmpty }
            // any close line with the same numbers means the reads agree, like two aspirin lines with different strengths
            guard !close.isEmpty, !close.contains(where: { $0.numbers == mine }) else { continue }
            guard let best = close.max(by: { overlap(lineWords, $0.words) < overlap(lineWords, $1.words) }) else { continue }
            found.append(Mismatch(line: line.trimmingCharacters(in: .whitespaces), other: best.text.trimmingCharacters(in: .whitespaces)))
        }
        return found
    }

    // plain lines for the patient, at most three
    static func notes(_ mismatches: [Mismatch], reader: String) -> [String] {
        mismatches.prefix(3).map {
            "\(reader) read a number two ways: \u{201C}\($0.line)\u{201D} or \u{201C}\($0.other)\u{201D}. Check it on the paper."
        }
    }

    // an ai reading checked against the camera reading of the same page
    // the ai text is kept for its layout, camera lines it skipped are added at the end so nothing is lost,
    // and every number the two read differently becomes a note
    static func combine(model: String, camera: [String], reader: String) -> (text: String, notes: [String]) {
        let modelLines = model.components(separatedBy: .newlines)
        let skipped = missing(from: model, camera: camera)
        var text = model
        var notes = notes(numberMismatches(kept: modelLines, other: camera), reader: "\(reader) and the camera")
        if !skipped.isEmpty {
            text += "\n\nAlso on the page:\n" + skipped.joined(separator: "\n")
            notes.append("\(reader) skipped \(PlainText.count(skipped.count, "line")) the camera saw. They were added at the end of the page.")
        }
        return (text, notes)
    }

    // camera lines with real words that the ai reading does not have
    static func missing(from model: String, camera: [String]) -> [String] {
        let have = Set(model.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return camera.filter { line in
            let lineWords = line.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 }
            guard lineWords.count >= 2 else { return false }
            let found = lineWords.filter(have.contains).count
            return Double(found) / Double(lineWords.count) < 0.5
        }
    }

    // a date or dose with a stray mark between digits like "1] 1/18/2026", never fixed by guessing
    static func smudged(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\d[\]\[|!]\s?\d+(?:[/.:]\d+)+"#) else { return [] }
        let ns = text as NSString
        let found = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        var seen: Set<String> = []
        return found.filter { seen.insert($0).inserted }
    }

    // plain lines for the patient about smudged numbers, at most three
    static func smudgeNotes(_ text: String) -> [String] {
        smudged(text).prefix(3).map {
            "A number looks smudged: \u{201C}\($0)\u{201D}. Check it on the paper."
        }
    }

    // MARK: - Helpers

    // only lines that could change what the patient does: a dose, a time, a day count or a medicine
    static func matters(_ line: String) -> Bool {
        if MedicalWords.isMedicineLine(line) { return true }
        let lower = line.lowercased()
        return ["day", "hour", "week", "before", "after", "every", "take", "stop", "tab"].contains { lower.contains($0) }
    }

    // numbers in order like 81, 0.5, 1/2
    static func numbers(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\d+(?:[.,/:]\d+)*"#) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    // words of three letters or more, used to match lines between the two reads
    private static func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 3 })
    }

    // how alike two lines are, 0 to 1
    private static func overlap(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }
}
