//
//  PageStructure.swift
//  Remedy
//
//  rebuilds a page's reading order lists and wrapped lines from where each piece of text sits
//  every piece the camera read ends up in the text exactly once so nothing is silently dropped
//

import Foundation
import CoreGraphics

// puts the camera's words back into lines, columns, lists and tables from where each word sits
nonisolated enum PageStructure {

    // one piece of text the camera read and where it sits 0 to 1 from the top left
    struct Piece: Equatable, Sendable {
        var text: String
        var box: CGRect
    }

    // a table the document reader found, used only when it holds the same words as the pieces under it
    struct Table: Equatable, Sendable {
        var box: CGRect
        var rows: [[String]]
    }

    // the page as plain text with blank lines between blocks and one line per list item
    // listStarts are boxes of list items the document reader saw, so a faint bullet still starts an item
    static func text(from pieces: [Piece], tables: [Table] = [], listStarts: [CGRect] = []) -> String {
        let kept = pieces.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty && $0.box.height > 0 }
        guard !kept.isEmpty else { return "" }
        let height = median(kept.map(\.box.height))

        // tables first so their words are not read twice
        var rest = kept
        var tableTexts: [(top: CGFloat, text: String)] = []
        // a real table has two or more filled cells in at least two rows, wrapped lines sometimes come back as one
        for table in tables where table.rows.filter({ $0.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count >= 2 }).count >= 2 {
            let inside = rest.filter { table.box.insetBy(dx: -height * 0.3, dy: -height * 0.3).contains(center($0.box)) }
            guard inside.count >= 2, covers(table, inside) else { continue }
            let text = table.rows.map { row in
                row.map(DocumentText.clean).joined(separator: "   ").trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }.joined(separator: "\n")
            guard !text.isEmpty else { continue }
            rest.removeAll { inside.contains($0) }
            tableTexts.append((table.box.minY, text))
        }

        // blocks keep the cut order and each table goes in before the first block below it
        var parts: [String] = []
        for block in cut(rest, height: height) {
            let top = union(block.map(\.box)).minY
            while let next = tableTexts.min(by: { $0.top < $1.top }), next.top < top {
                parts.append(next.text)
                tableTexts.removeAll { $0.top == next.top && $0.text == next.text }
            }
            let text = lines(of: block, height: height, listStarts: listStarts).joined(separator: "\n")
            if !text.isEmpty { parts.append(text) }
        }
        parts += tableTexts.sorted { $0.top < $1.top }.map(\.text)
        return parts.joined(separator: "\n\n")
    }

    // a photo taken at a slight angle tilts every line, so each piece is moved back level before rows are found
    // slope is how far a line drops per unit across, measured from the corners of the camera's long lines
    static func leveled(_ pieces: [Piece], slope: CGFloat) -> [Piece] {
        pieces.map { Piece(text: $0.text, box: leveled($0.box, slope: slope)) }
    }

    // one box moved back level, tables and list items use it too so they still line up with the words
    static func leveled(_ box: CGRect, slope: CGFloat) -> CGRect {
        guard abs(slope) > 0.003, abs(slope) < 0.2 else { return box }
        let middle = box.midY - slope * (box.midX - 0.5)
        let height = max(box.height - abs(slope) * box.width, box.height * 0.4)
        return CGRect(x: box.minX, y: middle - height / 2, width: box.width, height: height)
    }

    // the usual tilt of long lines, nil when there are too few to tell
    static func slope(of lines: [(left: CGPoint, right: CGPoint)]) -> CGFloat? {
        let slopes = lines.compactMap { line -> CGFloat? in
            let across = line.right.x - line.left.x
            guard across > 0.25 else { return nil }
            return (line.right.y - line.left.y) / across
        }
        guard slopes.count >= 3 else { return nil }
        return median(slopes)
    }

    // MARK: - Blocks

    // recursive xy cut: split at wide empty bands across the page, then at empty gutters between columns
    // a gutter only counts when both sides have two or more rows of real words, so justified gaps never split a line
    static func cut(_ pieces: [Piece], height: CGFloat, depth: Int = 0) -> [[Piece]] {
        guard pieces.count > 1, depth < 12 else { return pieces.isEmpty ? [] : [pieces] }

        let bands = split(pieces, along: \.minY, \.maxY, gap: height * 0.8)
        if bands.count > 1 {
            return bands.flatMap { cut($0, height: height, depth: depth + 1) }
        }

        let columns = split(pieces, along: \.minX, \.maxX, gap: height * 1.6)
        if columns.count > 1, columns.allSatisfy({ isColumn($0, height: height) }) {
            return columns.flatMap { cut($0, height: height, depth: depth + 1) }
        }
        return [pieces]
    }

    // groups pieces whose spans overlap along one axis, in order, breaking at gaps wider than gap
    private static func split(_ pieces: [Piece], along start: KeyPath<CGRect, CGFloat>, _ end: KeyPath<CGRect, CGFloat>,
                              gap: CGFloat) -> [[Piece]] {
        let sorted = pieces.sorted { $0.box[keyPath: start] < $1.box[keyPath: start] }
        var groups: [[Piece]] = []
        var reach = -CGFloat.infinity
        for piece in sorted {
            if groups.isEmpty || piece.box[keyPath: start] - reach > gap {
                groups.append([piece])
            } else {
                groups[groups.count - 1].append(piece)
            }
            reach = max(reach, piece.box[keyPath: end])
        }
        return groups
    }

    // a real column has at least two rows and is more than a column of bullet dots
    private static func isColumn(_ pieces: [Piece], height: CGFloat) -> Bool {
        let rows = split(pieces, along: \.midY, \.midY, gap: height * 0.5).count
        let wordy = pieces.contains { $0.text.filter { $0.isLetter || $0.isNumber }.count > 2 }
        return rows >= 2 && wordy
    }

    // MARK: - Lines in a block

    // one line of words across the page
    private struct Row {
        var text: String
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var bottom: CGFloat
        var height: CGFloat
        var startsItem: Bool
    }

    // rows in a block become lines, wrapped lines join their item or paragraph
    static func lines(of block: [Piece], height: CGFloat, listStarts: [CGRect] = []) -> [String] {
        let rows = rows(of: block, height: height, listStarts: listStarts)
        guard let blockLeft = rows.map(\.left).min(), let blockRight = rows.map(\.right).max() else { return [] }
        let width = max(blockRight - blockLeft, 0.0001)
        let itemLefts = rows.filter(\.startsItem).map(\.left)
        let firstItemLeft = itemLefts.min()

        var output: [String] = []
        var inItem = false
        var itemLeft: CGFloat = 0
        var previous: Row?

        for row in rows {
            defer { previous = row }
            let isHeading = isHeadingRow(row, height: height)
            if row.startsItem {
                let nested = firstItemLeft.map { row.left - $0 > height * 1.2 } ?? false
                output.append((nested ? "  " : "") + marked(row.text))
                inItem = true
                itemLeft = row.left
                continue
            }
            guard let previous, !isHeading, !output.isEmpty else {
                output.append(row.text)
                inItem = false
                continue
            }
            // a narrow block is an address or a side note, its lines are kept as printed
            let full = width >= 0.4 && previous.right >= blockRight - width * 0.18
            let longish = previous.right >= blockRight - width * 0.4
            let wraps = full || endsOpen(previous.text) || (startsLower(row.text) && longish)
            let isHeadingAbove = isHeadingRow(previous, height: height)

            // a faint bullet the camera dropped leaves the item starting where its text does, so level counts too
            if inItem && row.left > itemLeft - height * 0.3 {
                // under a bullet: a wrap joins the item, anything else stays as its own indented line
                if wraps && !isHeadingAbove {
                    output[output.count - 1] = join(output[output.count - 1], row.text)
                } else {
                    output.append("  " + row.text)
                }
                continue
            }
            inItem = false
            let sameLeft = abs(row.left - previous.left) < height * 1.2
            if wraps && sameLeft && !isHeadingAbove && !previous.text.hasSuffix(":") {
                output[output.count - 1] = join(output[output.count - 1], row.text)
            } else {
                output.append(row.text)
            }
        }
        return output
    }

    // clearly bigger short text, a photo makes some ordinary lines a little taller so size alone is not enough
    private static func isHeadingRow(_ row: Row, height: CGFloat) -> Bool {
        row.height > height * 1.5 && row.text.count < 60 && !row.startsItem && !endsOpen(row.text)
    }

    // pieces at the same height become one row, wide gaps between them become three spaces
    private static func rows(of block: [Piece], height: CGFloat, listStarts: [CGRect]) -> [Row] {
        var groups: [[Piece]] = []
        for piece in block.sorted(by: { $0.box.midY < $1.box.midY }) {
            if let last = groups.last, let lastMid = last.map(\.box.midY).max(), abs(piece.box.midY - lastMid) < height * 0.5 {
                groups[groups.count - 1].append(piece)
            } else {
                groups.append([piece])
            }
        }
        return groups.map { group in
            let pieces = group.sorted { $0.box.minX < $1.box.minX }
            var text = ""
            var before: Piece?
            for piece in pieces {
                let words = piece.text.trimmingCharacters(in: .whitespaces)
                if let before {
                    text += piece.box.minX - before.box.maxX > height * 3 ? "   " : " "
                }
                text += words
                before = piece
            }
            let box = union(pieces.map(\.box))
            let marker = hasMarker(text)
            let hinted = listStarts.contains { start in
                abs(start.minY - box.minY) < height * 0.6 && abs(start.minX - box.minX) < height * 2
            }
            return Row(text: text, left: box.minX, right: box.maxX, top: box.minY, bottom: box.maxY,
                       height: median(pieces.map(\.box.height)), startsItem: marker || hinted)
        }
    }

    // MARK: - Words

    // bullets numbers letters and boxes that start a list item
    static func hasMarker(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if DocumentText.bulleted(trimmed) != trimmed { return true }
        if trimmed.range(of: #"^(\(?[0-9]{1,2}[.)]|[a-hA-H][.)])\s+\S"#, options: .regularExpression) != nil { return true }
        // a dot the camera read as a middle dot or bullet with no space after it
        if let first = trimmed.unicodeScalars.first, ["\u{2022}", "\u{00B7}", "\u{25CF}", "\u{25AA}", "\u{25A0}"].contains(first),
           trimmed.count > 2 { return true }
        return false
    }

    // one bullet shape for all of them and numbers kept
    static func marked(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let bulleted = DocumentText.bulleted(trimmed)
        if bulleted != trimmed { return bulleted }
        if trimmed.range(of: #"^(\(?[0-9]{1,2}[.)]|[a-hA-H][.)])\s"#, options: .regularExpression) != nil { return trimmed }
        if let first = trimmed.unicodeScalars.first, ["\u{2022}", "\u{00B7}", "\u{25CF}", "\u{25AA}", "\u{25A0}"].contains(first) {
            return "\u{2022} " + String(trimmed.unicodeScalars.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return "\u{2022} " + trimmed
    }

    // a line that clearly goes on, like one ending in a comma or a dash
    private static func endsOpen(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        if ",-/&(".contains(last) { return true }
        let lower = text.lowercased()
        return [" and", " or", " the", " to", " of", " with", " for", " if", " a"].contains { lower.hasSuffix($0) }
    }

    // a line that starts lower case continues the line above
    private static func startsLower(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).first?.isLowercase ?? false
    }

    // a word split at the end of a line stays one word, everything else gets a space
    static func join(_ first: String, _ second: String) -> String {
        let head = first.trimmingCharacters(in: .whitespaces)
        let tail = second.trimmingCharacters(in: .whitespaces)
        if let last = head.last, (last == "-" || last == "/"), head.dropLast().last?.isLetter ?? false,
           tail.first?.isLetter ?? false {
            return head + tail
        }
        return head + " " + tail
    }

    // MARK: - Helpers

    // true when the table holds most of the words in the pieces, so they are not printed twice
    private static func covers(_ table: Table, _ pieces: [Piece]) -> Bool {
        let tableWords = Set(words(table.rows.flatMap { $0 }.joined(separator: " ")))
        let pieceWords = words(pieces.map(\.text).joined(separator: " "))
        guard !pieceWords.isEmpty else { return false }
        let found = pieceWords.filter(tableWords.contains).count
        return Double(found) / Double(pieceWords.count) >= 0.95
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    // the typical line height, used to tell a new line from a new paragraph
    static func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0.02 }
        return values.sorted()[values.count / 2]
    }

    private static func center(_ box: CGRect) -> CGPoint { CGPoint(x: box.midX, y: box.midY) }

    private static func union(_ boxes: [CGRect]) -> CGRect {
        boxes.dropFirst().reduce(boxes.first ?? .zero) { $0.union($1) }
    }
}
