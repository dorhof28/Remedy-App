//
//  PaperLayout.swift
//  Remedy
//
//  plain rules that turn the words of a page into headings, bullets, medicine lines and paragraphs
//  every word keeps its piece number so a tap still hides the right one
//

import Foundation

// turns a hidden page's pieces into lines the page view can draw: headings, bullets, numbered and plain
nonisolated enum PaperLayout {

    enum Kind: Equatable {
        case heading
        case bullet         // the marker is dropped, the view draws its own dot
        case numbered       // keeps its own number
        case medicine       // a line with a dose, drawn indented
        case paragraph
        case spacer
    }

    // a bit of a line, piece is the number in the page's pieces, nil for a space added when lines join
    struct Segment: Equatable {
        var text: String
        var piece: Int?
    }

    struct Line: Equatable {
        var kind: Kind
        var segments: [Segment]
        var text: String { segments.map(\.text).joined() }
    }

    // MARK: - Lines

    // groups pieces into lines, breaking where the camera saw a new line
    static func lines(from pieces: [RedactedPiece]) -> [Line] {
        var rawLines: [[Segment]] = []
        var current: [Segment] = []
        for (index, piece) in pieces.enumerated() {
            if piece.isHidden || piece.isWord {
                current.append(Segment(text: piece.isHidden ? Redactor.mark : piece.text, piece: index))
                continue
            }
            for (number, part) in piece.text.components(separatedBy: "\n").enumerated() {
                if number > 0 {
                    rawLines.append(current)
                    current = []
                }
                if !part.isEmpty { current.append(Segment(text: part, piece: index)) }
            }
        }
        rawLines.append(current)

        var result: [Line] = []
        for raw in rawLines {
            let line = classify(raw)
            if line.kind == .spacer {
                // one blank line at most and none at the start
                if let last = result.last, last.kind != .spacer { result.append(line) }
                continue
            }
            // a wrapped sentence joins the line before it
            if line.kind == .paragraph, let last = result.last, last.kind == .paragraph, !endsSentence(last.text) {
                result[result.count - 1].segments += [Segment(text: " ", piece: nil)] + trimmed(line.segments)
                continue
            }
            result.append(line)
        }
        while result.last?.kind == .spacer { result.removeLast() }
        return result
    }

    // MARK: - Rules

    // bold marks from the reader are dropped, the words stay
    private static func tidied(_ segments: [Segment]) -> [Segment] {
        segments.map { Segment(text: $0.text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: ""), piece: $0.piece) }
    }

    private static let dose = try? NSRegularExpression(
        pattern: #"\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu|units?|tablets?|pills?|capsules?|puffs?|drops?)\b"#,
        options: .caseInsensitive)

    // decides if a line is a heading, bullet, numbered or plain text
    private static func classify(_ raw: [Segment]) -> Line {
        var segments = trimmed(tidied(raw))
        var text = segments.map(\.text).joined()
        guard !text.isEmpty else { return Line(kind: .spacer, segments: []) }

        // a table row from the reader reads as cells with dots between, the dash row under a header is dropped
        if text.hasPrefix("|") {
            if text.allSatisfy({ "|-: ".contains($0) }) { return Line(kind: .spacer, segments: []) }
            segments = trimmed(segments.map { Segment(text: $0.text.replacingOccurrences(of: "|", with: " \u{00B7} "), piece: $0.piece) })
            segments = stripMarker(segments, markers: "\u{00B7}")
            if let last = segments.indices.last, segments[last].text.hasSuffix("\u{00B7}") {
                segments[last].text = String(segments[last].text.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            text = segments.map(\.text).joined()
            guard !text.isEmpty else { return Line(kind: .spacer, segments: []) }
            // each row stays its own line, never joined to a sentence
            return Line(kind: matches(dose, text) ? .medicine : .bullet, segments: segments)
        }

        // markdown style heading
        if text.hasPrefix("#") {
            return Line(kind: .heading, segments: stripMarker(segments, markers: "#"))
        }
        if let first = text.first, "-*\u{2022}\u{2013}\u{25CF}\u{25AA}".contains(first), text.dropFirst().first == " " {
            let rest = stripMarker(segments, markers: "-*\u{2022}\u{2013}\u{25CF}\u{25AA}")
            let kind: Kind = matches(dose, rest.map(\.text).joined()) ? .medicine : .bullet
            return Line(kind: kind, segments: rest)
        }
        if text.range(of: #"^\d{1,2}[.)]\s"#, options: .regularExpression) != nil {
            return Line(kind: .numbered, segments: segments)
        }
        if isHeadingText(text) { return Line(kind: .heading, segments: segments) }
        if matches(dose, text) { return Line(kind: .medicine, segments: segments) }
        return Line(kind: .paragraph, segments: segments)
    }

    // all capitals or a few words ending in a colon
    private static func isHeadingText(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter)
        if letters.count >= 3, letters == letters.uppercased(), text.count <= 60 { return true }
        return text.hasSuffix(":") && text.split(separator: " ").count <= 6
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return true }
        return ".!?:".contains(last)
    }

    private static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // removes spaces from both ends
    private static func trimmed(_ segments: [Segment]) -> [Segment] {
        var result = segments
        while let first = result.first, first.piece == nil || first.text.allSatisfy(\.isWhitespace) {
            result.removeFirst()
        }
        while let last = result.last, last.text.allSatisfy(\.isWhitespace) { result.removeLast() }
        if var first = result.first, first.text.first?.isWhitespace == true {
            first.text = String(first.text.drop(while: \.isWhitespace))
            result[0] = first
        }
        if var last = result.last, last.text.last?.isWhitespace == true {
            last.text = String(last.text.reversed().drop(while: \.isWhitespace).reversed())
            result[result.count - 1] = last
        }
        return result.filter { !$0.text.isEmpty }
    }

    // takes the marker and the space after it off the front of the first segment
    private static func stripMarker(_ segments: [Segment], markers: String) -> [Segment] {
        var result = segments
        guard var first = result.first else { return result }
        first.text = String(first.text.drop(while: { markers.contains($0) || $0.isWhitespace }))
        if first.text.isEmpty { result.removeFirst() } else { result[0] = first }
        return result
    }
}
