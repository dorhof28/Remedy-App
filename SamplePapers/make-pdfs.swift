// renders papers/*.md to one page pdfs in pdfs/
// run: swift SamplePapers/make-pdfs.swift

import AppKit
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let papers = root.appendingPathComponent("papers")
let out = root.appendingPathComponent("pdfs")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let files = ((try? FileManager.default.contentsOfDirectory(atPath: papers.path)) ?? []).filter { $0.hasSuffix(".md") }.sorted()

func line(_ text: String, size: CGFloat, bold: Bool = false) -> NSAttributedString {
    let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    let style = NSMutableParagraphStyle()
    style.paragraphSpacing = size * 0.45
    style.lineSpacing = 2
    return NSAttributedString(string: text + "\n", attributes: [.font: font, .paragraphStyle: style, .foregroundColor: NSColor.black])
}

var made = 0
for file in files {
    let text = (try? String(contentsOf: papers.appendingPathComponent(file), encoding: .utf8)) ?? ""
    let body = NSMutableAttributedString()
    var footer = ""
    for raw in text.components(separatedBy: "\n") {
        if raw.hasPrefix("# ") { body.append(line(String(raw.dropFirst(2)), size: 20, bold: true)) }
        else if raw.hasPrefix("## ") { body.append(line(String(raw.dropFirst(3)), size: 14, bold: true)) }
        else if raw.hasPrefix("- ") { body.append(line("\u{2022} " + raw.dropFirst(2), size: 12)) }
        else if raw.hasPrefix("  ") { body.append(line("    " + raw.trimmingCharacters(in: .whitespaces), size: 12)) }
        else if raw.contains("SAMPLE - NOT A REAL PATIENT") { footer = raw }
        else if raw.isEmpty { continue }
        else { body.append(line(raw, size: 12)) }
    }
    let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    let url = out.appendingPathComponent(file.replacingOccurrences(of: ".md", with: ".pdf"))
    var box = page
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { continue }
    context.beginPDFPage(nil)
    let setter = CTFramesetterCreateWithAttributedString(body)
    let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0),
                                         CGPath(rect: CGRect(x: 54, y: 90, width: 504, height: 650), transform: nil), nil)
    CTFrameDraw(frame, context)
    let foot = NSAttributedString(string: footer, attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.darkGray])
    context.textPosition = CGPoint(x: 54, y: 50)
    CTLineDraw(CTLineCreateWithAttributedString(foot), context)
    context.endPDFPage()
    context.closePDF()
    made += 1
}
print("made \(made) pdfs in \(out.path)")
