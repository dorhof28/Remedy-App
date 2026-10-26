//
//  TextReader.swift
//  Remedy
//
//  reads the words on a scanned page with vision keeping rows lists and columns
//

import Foundation
import UIKit
import Vision
import os

// one piece of text and where it sits 0 to 1 from the top left
struct ScannedLine {
    let text: String
    let box: CGRect
}

// a page with its laid out text and the picture
struct ScannedPage {
    var text: String
    var lines: [ScannedLine] = []
    var barcodes: [CGRect] = []     // patient stickers often have one
    var image: UIImage? = nil
}

enum TextReader {

    private static let log = Logger(subsystem: "Remedy", category: "Reading")

    // text only for older callers
    static func read(_ images: [UIImage]) async -> [String] {
        await scan(images).map(\.text)
    }

    static func read(_ image: UIImage) async -> String {
        await scan(image).text
    }

    // every page in order
    static func scan(_ images: [UIImage]) async -> [ScannedPage] {
        var pages: [ScannedPage] = []
        for image in images {
            pages.append(await scan(image))
        }
        return pages
    }

    // reads one page and puts the words back in rows
    static func scan(_ photo: UIImage) async -> ScannedPage {
        let image = upright(photo)
        guard let cgImage = image.cgImage else { return ScannedPage(text: "") }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true      // fixes "lbuprofen" -> "Ibuprofen"
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.customWords = MedicalWords.visionWords

        do {
            let observations = try await request.perform(on: cgImage)
            let lines: [ScannedLine] = observations.compactMap { observation in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                let box = observation.boundingBox.cgRect
                // vision measures from the bottom left
                return ScannedLine(text: text, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
            }
            var barcodes: [CGRect] = []
            if let found = try? await DetectBarcodesRequest().perform(on: cgImage) {
                for observation in found {
                    let box = observation.boundingBox.cgRect
                    barcodes.append(CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
                }
            }
            return ScannedPage(text: layout(lines), lines: lines, barcodes: barcodes, image: image)
        } catch {
            log.error("Could not read page: \(error.localizedDescription)")
            return ScannedPage(text: "", image: image)
        }
    }

    // MARK: - Layout

    // groups pieces into rows then adds gaps indents and bullets
    static func layout(_ lines: [ScannedLine]) -> String {
        guard !lines.isEmpty else { return "" }
        let left = lines.map(\.box.minX).sorted()[lines.count / 20]      // ignores a stray piece near the edge
        let typicalHeight = lines.map(\.box.height).sorted()[lines.count / 2]

        // rows of pieces that sit at the same height
        var rows: [[ScannedLine]] = []
        for line in lines.sorted(by: { $0.box.midY < $1.box.midY }) {
            if let last = rows.last?.last, abs(line.box.midY - last.box.midY) < typicalHeight * 0.5 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }

        var output: [String] = []
        var lastBottom: CGFloat?
        for row in rows {
            let pieces = row.sorted { $0.box.minX < $1.box.minX }
            let top = pieces.map(\.box.minY).min() ?? 0

            // a big gap above means a new paragraph
            if let lastBottom, top - lastBottom > typicalHeight * 1.2 { output.append("") }
            lastBottom = pieces.map(\.box.maxY).max()

            // wide gaps between pieces are columns
            var text = ""
            var previous: ScannedLine?
            for piece in pieces {
                if let previous {
                    text += piece.box.minX - previous.box.maxX > typicalHeight * 1.5 ? "   " : " "
                }
                text += piece.text
                previous = piece
            }

            let indent = max(0, min(3, Int(((pieces.first?.box.minX ?? left) - left) / 0.035)))
            output.append(String(repeating: "  ", count: indent) + bulleted(text))
        }
        return output.joined(separator: "\n")
    }

    // turns the many bullet shapes on paper into one
    private static func bulleted(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for bullet in ["\u{2022}", "\u{25CF}", "\u{25AA}", "\u{25A0}", "\u{25E6}", "\u{25CB}", "\u{00B7}", "\u{F0B7}", "-", "*", ">", "o"]
        where trimmed.hasPrefix(bullet + " ") {
            return "\u{2022} " + trimmed.dropFirst(bullet.count + 1).trimmingCharacters(in: .whitespaces)
        }
        for box in ["\u{2610}", "\u{25A1}", "[ ]", "[]"] where trimmed.hasPrefix(box) {
            return "\u{2610} " + trimmed.dropFirst(box.count).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    // MARK: - Picture

    // turns the photo the right way up and no bigger than 2400 pixels
    static func upright(_ photo: UIImage) -> UIImage {
        let longest = max(photo.size.width, photo.size.height)
        let scale = min(1, 2400 / max(longest, 1))
        let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
