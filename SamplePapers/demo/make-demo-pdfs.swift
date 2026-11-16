// renders demo/papers/*.md to after visit summary style pdfs in demo/pdfs/
// run: swift SamplePapers/demo/make-demo-pdfs.swift
// layout follows the common epic printout: gray header, logo box, vitals grid, date column, page footer
//
// markup
// ---  front block: title logo patient mrn ceid date place printed
// ## Title  from someone      big light section title with a small gray from
// ### Heading                 bold heading, "### ^Heading" centered
// #### Title                  light small title with a box icon, like Done Today
// 1. text                     numbered item with a hanging indent
// - text / ·- text            bullet / second level bullet
// "  text"                    indented line under a bullet
// **bold** __bold underlined__ {gray text}
// [[vitals: Label 1 | Label 2]]      big four across grid, the value starts at the first number
// [[table: Label=value | ...]]       small five across table
// [[date: NOV 5 2026]] text          what's next row, indented lines after it join the row
// [[med: name | strength]]           medication row, indented lines after it join the row
// [[box: text]]                      shaded note box
// ::: columns / ||| / :::            two columns
// ---page                            new page

import AppKit
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let papers = root.appendingPathComponent("papers")
let out = root.appendingPathComponent("pdfs")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792
let left: CGFloat = 54, right: CGFloat = 558, top: CGFloat = 58, bottom: CGFloat = 722
let textWidth = right - left

let gray = NSColor(white: 0.42, alpha: 1)
let lightGray = NSColor(white: 0.58, alpha: 1)
let ink = NSColor(white: 0.1, alpha: 1)
let sampleRed = NSColor(red: 0.8, green: 0.05, blue: 0.05, alpha: 1)

func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont { NSFont.systemFont(ofSize: size, weight: weight) }

// text with **bold**, __bold underlined__ and {gray} runs
func styled(_ text: String, size: CGFloat = 10.5, color: NSColor = ink, indent: CGFloat = 0, hanging: CGFloat = 0, align: NSTextAlignment = .left) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 2.5
    style.firstLineHeadIndent = indent
    style.headIndent = indent + hanging
    style.alignment = align
    let result = NSMutableAttributedString()
    var bold = false, underline = false, dim = false
    var run = ""
    func flush() {
        guard !run.isEmpty else { return }
        var attributes: [NSAttributedString.Key: Any] = [.font: font(size, bold || underline ? .bold : .regular),
                                                         .foregroundColor: dim ? lightGray : color, .paragraphStyle: style]
        if underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        result.append(NSAttributedString(string: run, attributes: attributes))
        run = ""
    }
    var index = text.startIndex
    while index < text.endIndex {
        let rest = text[index...]
        if rest.hasPrefix("**") { flush(); bold.toggle(); index = text.index(index, offsetBy: 2); continue }
        if rest.hasPrefix("__") { flush(); underline.toggle(); index = text.index(index, offsetBy: 2); continue }
        if text[index] == "{" { flush(); dim = true; index = text.index(after: index); continue }
        if text[index] == "}" { flush(); dim = false; index = text.index(after: index); continue }
        run.append(text[index])
        index = text.index(after: index)
    }
    flush()
    return result
}

// one piece of the page with its height and how to draw it at a top y
struct Block {
    let height: CGFloat
    let draw: (CGContext, CGFloat) -> Void
    var keepsWithNext = false   // titles never sit alone at the bottom of a page
    var breaksPage = false
}

func measure(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
    let setter = CTFramesetterCreateWithAttributedString(text)
    let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil,
                                                            CGSize(width: width, height: .greatestFiniteMagnitude), nil)
    return ceil(size.height)
}

func drawText(_ text: NSAttributedString, in context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    let setter = CTFramesetterCreateWithAttributedString(text)
    let rect = CGRect(x: x, y: pageHeight - y - height - 2, width: width, height: height + 2)
    let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
    CTFrameDraw(frame, context)
}

func textBlock(_ text: NSAttributedString, x: CGFloat = left, width: CGFloat = textWidth, after: CGFloat = 5) -> Block {
    let height = measure(text, width: width)
    return Block(height: height + after) { context, y in drawText(text, in: context, x: x, y: y, width: width, height: height) }
}

func space(_ height: CGFloat) -> Block { Block(height: height) { _, _ in } }

func line(_ context: CGContext, from x1: CGFloat, to x2: CGFloat, at y: CGFloat, white: CGFloat = 0.84) {
    context.setStrokeColor(NSColor(white: white, alpha: 1).cgColor)
    context.setLineWidth(0.8)
    context.move(to: CGPoint(x: x1, y: pageHeight - y))
    context.addLine(to: CGPoint(x: x2, y: pageHeight - y))
    context.strokePath()
}

func rule() -> Block { Block(height: 20) { context, y in line(context, from: left, to: right, at: y + 9) } }

// "Instructions  from Dr. Brooks" as a big light title and a small gray from
func sectionTitle(_ raw: String) -> Block {
    let parts = raw.components(separatedBy: "  ")
    let title = NSMutableAttributedString(string: parts[0], attributes: [.font: font(18, .light), .foregroundColor: gray])
    if parts.count > 1 {
        title.append(NSAttributedString(string: "  " + parts.dropFirst().joined(separator: " "), attributes: [.font: font(9.5), .foregroundColor: lightGray]))
    }
    var block = textBlock(title, after: 7)
    block.keepsWithNext = true
    return block
}

// label over value, four to a row, the value starts at the first number
func vitals(_ raw: String) -> Block {
    let cells = raw.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.map { item -> (String, String) in
        let words = item.components(separatedBy: " ")
        let start = words.firstIndex { $0.first?.isNumber == true } ?? words.count - 1
        return (words[..<start].joined(separator: " "), words[start...].joined(separator: " "))
    }
    let cellWidth = textWidth / 4
    return Block(height: CGFloat((cells.count + 3) / 4) * 38 + 8) { context, y in
        for (index, cell) in cells.enumerated() {
            let x = left + CGFloat(index % 4) * cellWidth
            let rowY = y + CGFloat(index / 4) * 38
            // a small round icon like the printout
            context.setStrokeColor(NSColor(white: 0.75, alpha: 1).cgColor)
            context.setLineWidth(0.8)
            context.strokeEllipse(in: CGRect(x: x, y: pageHeight - rowY - 24, width: 18, height: 18))
            drawText(NSAttributedString(string: cell.0, attributes: [.font: font(8.5), .foregroundColor: lightGray]), in: context, x: x + 24, y: rowY, width: cellWidth - 26, height: 12)
            drawText(NSAttributedString(string: cell.1, attributes: [.font: font(14), .foregroundColor: ink]), in: context, x: x + 24, y: rowY + 11, width: cellWidth - 26, height: 20)
        }
    }
}

// small label over value, five to a row
func table(_ raw: String) -> Block {
    let cells = raw.components(separatedBy: "|").map { item -> (String, String) in
        let pair = item.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        return (pair.first ?? "", pair.count > 1 ? pair[1] : "")
    }
    let cellWidth = textWidth / 5
    // each row is as tall as its tallest value so long values wrap
    let rowCount = (cells.count + 4) / 5
    let rowHeights = (0..<rowCount).map { row in
        cells[(row * 5)..<min(cells.count, row * 5 + 5)].map { measure(styled($0.1, size: 9.5), width: cellWidth - 8) }.max() ?? 12
    }
    return Block(height: rowHeights.reduce(0) { $0 + $1 + 22 } + 2) { context, y in
        var rowY = y
        for row in 0..<rowCount {
            for column in 0..<5 where row * 5 + column < cells.count {
                let cell = cells[row * 5 + column]
                let x = left + CGFloat(column) * cellWidth
                drawText(NSAttributedString(string: cell.0, attributes: [.font: font(8.5), .foregroundColor: lightGray]), in: context, x: x, y: rowY, width: cellWidth - 8, height: 12)
                drawText(styled(cell.1, size: 9.5), in: context, x: x, y: rowY + 12, width: cellWidth - 8, height: rowHeights[row])
            }
            rowY += rowHeights[row] + 22
        }
    }
}

// month day year stacked on the left, the visit on the right
func dated(_ date: String, _ text: String, _ more: [String]) -> Block {
    let parts = date.components(separatedBy: " ")
    let body = NSMutableAttributedString(attributedString: styled(text, size: 11, color: gray))
    for extra in more { body.append(styled("\n" + extra, size: 10)) }
    let width = textWidth - 46
    let height = max(measure(body, width: width), 44)
    return Block(height: height + 14) { context, y in
        let stack: [(String, NSFont)] = [(parts[0], font(7.5)), (parts.count > 1 ? parts[1] : "", font(15)), (parts.count > 2 ? parts[2] : "", font(7.5))]
        var rowY = y
        for (word, wordFont) in stack {
            drawText(NSAttributedString(string: word, attributes: [.font: wordFont, .foregroundColor: lightGray]), in: context, x: left, y: rowY, width: 40, height: wordFont.pointSize + 4)
            rowY += wordFont.pointSize + 3
        }
        drawText(body, in: context, x: left + 46, y: y, width: width, height: height)
    }
}

// a medication row: "aspirin | 81 MG EC tablet" draws the name in gray and the strength small and dark
// then "Commonly known as" in light gray and any other lines in small dark type, then a thin line
func med(_ name: String, _ more: [String]) -> Block {
    let parts = name.components(separatedBy: " | ")
    let body = NSMutableAttributedString(attributedString: styled(parts[0], size: 12, color: gray))
    if parts.count > 1 { body.append(styled(" " + parts[1], size: 9.5)) }
    for extra in more {
        let known = extra.hasPrefix("Commonly known as")
        body.append(styled("\n" + extra, size: known ? 8.5 : 9.5, color: known ? lightGray : ink))
    }
    let height = measure(body, width: textWidth)
    return Block(height: height + 11) { context, y in
        drawText(body, in: context, x: left, y: y, width: textWidth, height: height)
        line(context, from: left, to: right, at: y + height + 5, white: 0.9)
    }
}

func box(_ text: String) -> Block {
    let body = styled(text, size: 10)
    let height = measure(body, width: textWidth - 24)
    // room above the box so it does not touch the line before
    return Block(height: height + 32) { context, y in
        context.setFillColor(NSColor(white: 0.93, alpha: 1).cgColor)
        context.fill(CGRect(x: left, y: pageHeight - y - height - 24, width: textWidth, height: height + 14))
        drawText(body, in: context, x: left + 12, y: y + 17, width: textWidth - 24, height: height)
    }
}

func columns(_ leftLines: [String], _ rightLines: [String]) -> Block {
    let leftWidth = textWidth * 0.56, gap: CGFloat = 24
    let rightWidth = textWidth - leftWidth - gap
    let leftText = styled(leftLines.joined(separator: "\n"))
    let rightText = styled(rightLines.joined(separator: "\n"))
    let height = max(measure(leftText, width: leftWidth), measure(rightText, width: rightWidth))
    return Block(height: height + 8) { context, y in
        drawText(leftText, in: context, x: left, y: y, width: leftWidth, height: height)
        drawText(rightText, in: context, x: left + leftWidth + gap, y: y, width: rightWidth, height: height)
    }
}

func header(_ meta: [String: String]) -> Block {
    Block(height: 84) { context, y in
        drawText(NSAttributedString(string: meta["title"] ?? "", attributes: [.font: font(21, .light), .foregroundColor: gray]),
                 in: context, x: left, y: y + 14, width: 380, height: 28)
        let name = NSMutableAttributedString(string: (meta["patient"] ?? "") + "   ", attributes: [.font: font(11, .semibold), .foregroundColor: ink])
        name.append(NSAttributedString(string: "MRN: \(meta["mrn"] ?? "")", attributes: [.font: font(9), .foregroundColor: lightGray]))
        drawText(name, in: context, x: left, y: y + 44, width: 300, height: 14)
        drawText(NSAttributedString(string: "CEID: \(meta["ceid"] ?? "")", attributes: [.font: font(8), .foregroundColor: lightGray]),
                 in: context, x: left, y: y + 59, width: 300, height: 12)
        // gray logo box with white letters
        let box = CGRect(x: right - 52, y: pageHeight - y - 50, width: 52, height: 48)
        context.setFillColor(NSColor(white: 0.6, alpha: 1).cgColor)
        context.fill(box)
        let logo = NSAttributedString(string: meta["logo"] ?? "", attributes: [.font: font(14, .heavy), .foregroundColor: NSColor.white])
        let logoWidth = logo.size().width
        drawText(logo, in: context, x: box.midX - logoWidth / 2, y: y + 17, width: logoWidth + 4, height: 18)
        let when = NSMutableAttributedString(string: "\u{25A3} ", attributes: [.font: font(8.5), .foregroundColor: lightGray])
        when.append(NSAttributedString(string: meta["date"] ?? "", attributes: [.font: font(8.5), .foregroundColor: lightGray]))
        when.append(NSAttributedString(string: "    \u{25C9} " + (meta["place"] ?? ""), attributes: [.font: font(8.5), .foregroundColor: lightGray]))
        drawText(when, in: context, x: right - 300, y: y + 58, width: 300, height: 24)
    }
}

func sampleLine(_ context: CGContext, at y: CGFloat) {
    drawText(styled("SAMPLE - NOT A REAL PATIENT", size: 10, color: sampleRed, align: .center)
                .withBold(), in: context, x: left, y: y, width: textWidth, height: 14)
}

extension NSAttributedString {
    func withBold() -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: self)
        copy.addAttribute(.font, value: font(10, .bold), range: NSRange(location: 0, length: length))
        return copy
    }
}

// reads the indented lines under a row
func indented(_ lines: [String], from index: inout Int) -> [String] {
    var more: [String] = []
    while index < lines.count, lines[index].hasPrefix("  ") {
        more.append(lines[index].trimmingCharacters(in: .whitespaces))
        index += 1
    }
    return more
}

var made = 0
let files = ((try? FileManager.default.contentsOfDirectory(atPath: papers.path)) ?? []).filter { $0.hasSuffix(".md") }.sorted()
for file in files {
    let text = (try? String(contentsOf: papers.appendingPathComponent(file), encoding: .utf8)) ?? ""
    var lines = text.components(separatedBy: "\n")

    // front block between --- lines
    var meta: [String: String] = [:]
    if lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") {
        for entry in lines[1..<end] {
            let pair = entry.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if pair.count == 2 { meta[pair[0]] = pair[1] }
        }
        lines = Array(lines[(end + 1)...])
    }

    var blocks: [Block] = [header(meta), rule()]
    var index = 0
    // the kind of the last line so a plain paragraph after a list gets some room
    var lastKind = ""
    while index < lines.count {
        let raw = lines[index]
        index += 1
        let kind = raw.hasPrefix("[[med:") ? "med" : raw.hasPrefix("- ") || raw.hasPrefix("·- ") || raw.hasPrefix("  ") ? "list"
            : raw.first?.isNumber == true ? "number" : raw.hasPrefix("[[") || raw.hasPrefix("#") || raw.hasPrefix(":::") ? "other" : raw.isEmpty ? lastKind : "plain"
        defer { lastKind = kind }
        if raw.isEmpty || raw.contains("SAMPLE - NOT A REAL PATIENT") { continue }
        if raw == "---page" {
            var block = space(0)
            block.breaksPage = true
            blocks.append(block)
        } else if raw.hasPrefix("## ") {
            if let last = blocks.last, !last.breaksPage, blocks.count > 2 { blocks.append(rule()) }
            blocks.append(sectionTitle(String(raw.dropFirst(3))))
        } else if raw.hasPrefix("#### ") {
            // a light small title like "Done Today" with its little box icon
            blocks.append(space(6))
            var block = textBlock(styled("\u{229E} " + raw.dropFirst(5), size: 11.5, color: gray), after: 4)
            block.keepsWithNext = true
            blocks.append(block)
        } else if raw.hasPrefix("### ^") {
            // a centered heading like "Directions for Your Medications Preoperatively"
            blocks.append(space(3))
            var block = textBlock(styled(String(raw.dropFirst(5)), size: 11, align: .center), after: 10)
            block.keepsWithNext = true
            blocks.append(block)
        } else if raw.hasPrefix("### ") {
            blocks.append(space(3))
            var block = textBlock(styled("**" + raw.dropFirst(4) + "**", size: 11), after: 6)
            block.keepsWithNext = true
            blocks.append(block)
        } else if raw.hasPrefix("[[vitals:") {
            blocks.append(vitals(String(raw.dropFirst(9).dropLast(2))))
        } else if raw.hasPrefix("[[table:") {
            blocks.append(table(String(raw.dropFirst(8).dropLast(2))))
        } else if raw.hasPrefix("[[box:") {
            // a note box stays on the page with the row above it
            if !blocks.isEmpty { blocks[blocks.count - 1].keepsWithNext = true }
            blocks.append(box(String(raw.dropFirst(6).dropLast(2)).trimmingCharacters(in: .whitespaces)))
        } else if raw.hasPrefix("[[med:") {
            let name = String(raw.dropFirst(6).dropLast(2)).trimmingCharacters(in: .whitespaces)
            if lastKind != "med" { blocks.append(space(8)) }
            blocks.append(med(name, indented(lines, from: &index)))
        } else if raw.hasPrefix("[[date:"), let close = raw.range(of: "]]") {
            let date = String(raw[raw.index(raw.startIndex, offsetBy: 7)..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rest = String(raw[close.upperBound...]).trimmingCharacters(in: .whitespaces)
            blocks.append(dated(date, rest, indented(lines, from: &index)))
        } else if raw == "::: columns" {
            var leftLines: [String] = [], rightLines: [String] = [], onRight = false
            while index < lines.count, lines[index] != ":::" {
                if lines[index] == "|||" { onRight = true } else if onRight { rightLines.append(lines[index]) } else { leftLines.append(lines[index]) }
                index += 1
            }
            index += 1
            blocks.append(columns(leftLines, rightLines))
        } else if raw.hasPrefix("·- ") {
            blocks.append(textBlock(styled("\u{25E6}  " + raw.dropFirst(3), indent: 44, hanging: 11), after: 2))
        } else if raw.hasPrefix("- ") {
            blocks.append(textBlock(styled("\u{2022}  " + raw.dropFirst(2), indent: 26, hanging: 11), after: 3))
        } else if raw.hasPrefix("  ") {
            blocks.append(textBlock(styled(raw.trimmingCharacters(in: .whitespaces), indent: 20), after: 3))
        } else if let dot = raw.firstIndex(of: "."), !raw[..<dot].isEmpty, raw[..<dot].allSatisfy(\.isNumber) {
            blocks.append(space(4))
            blocks.append(textBlock(styled(raw, indent: 8, hanging: 14), after: 4))
        } else {
            // a bold lead in line starts a new group so it gets room above
            if lastKind == "list" || lastKind == "number" || (raw.hasPrefix("**") && lastKind == "plain") { blocks.append(space(8)) }
            blocks.append(textBlock(styled(raw), after: 6))
        }
    }

    // lay blocks onto pages
    var pages: [[(Block, CGFloat)]] = [[]]
    var y = top
    for (number, block) in blocks.enumerated() {
        if block.breaksPage {
            if !pages[pages.count - 1].isEmpty { pages.append([]); y = top + 26 }
            continue
        }
        let next = block.keepsWithNext && number + 1 < blocks.count ? blocks[number + 1].height : 0
        if y + block.height + next > bottom, !pages[pages.count - 1].isEmpty {
            pages.append([])
            y = top + 26
        }
        pages[pages.count - 1].append((block, y))
        y += block.height
    }

    let url = out.appendingPathComponent(file.replacingOccurrences(of: ".md", with: ".pdf"))
    var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { continue }
    for (number, page) in pages.enumerated() {
        context.beginPDFPage(nil)
        sampleLine(context, at: 26)
        for (block, y) in page { block.draw(context, y) }
        // footer like the printout
        let foot = NSMutableAttributedString(string: meta["patient"] ?? "", attributes: [.font: font(9), .foregroundColor: ink])
        foot.append(NSAttributedString(string: " (MRN: \(meta["mrn"] ?? ""))  \u{2022}  Printed at \(meta["printed"] ?? "")", attributes: [.font: font(9), .foregroundColor: ink]))
        drawText(foot, in: context, x: left, y: 738, width: 360, height: 12)
        drawText(styled("Page \(number + 1) of \(pages.count)", size: 9, align: .right),
                 in: context, x: right - 90, y: 738, width: 90, height: 12)
        sampleLine(context, at: 756)
        context.endPDFPage()
    }
    context.closePDF()
    made += 1
    print("\(file): \(pages.count) pages")
}
print("made \(made) pdfs in \(out.path)")
