//
//  TextReader.swift
//  Remedy
//
//  reads the words on a photo or scan of a paper with vision on this iphone
//  the page is cut out and squared up, read, read again with shadows lifted if it was hard,
//  then PageStructure puts columns lists and wrapped lines back together from where each word sits
//

import Foundation
import UIKit
import Vision
import os

// one piece of text and where it sits 0 to 1 from the top left
struct ScannedLine {
    let text: String
    let box: CGRect
    var confidence: Float = 1
}

// a page with its laid out text and the picture
struct ScannedPage {
    var text: String
    var lines: [ScannedLine] = []
    var barcodes: [CGRect] = []     // patient stickers often have one
    var image: UIImage? = nil
    // things the patient should check on this page, like a number two reads disagree on
    var notes: [String] = []

    // how much of the page was read with confidence, used to pick the better of two reads
    var score: Double {
        lines.reduce(0) { $0 + Double($1.confidence) * Double($1.text.count) }
    }
}

// reads the words on a page photo with vision
enum TextReader {

    private static let log = Logger(subsystem: "Remedy", category: "Reading")

    // text only for older callers
    static func read(_ images: [UIImage]) async -> [String] {
        await scan(images).map(\.text)
    }

    static func read(_ image: UIImage) async -> String {
        await scan(image).text
    }

    // every page in order, with an ai reader next to the camera when the patient picked one
    static func scan(_ images: [UIImage], modelReader: PageModelReader? = nil) async -> [ScannedPage] {
        var pages: [ScannedPage] = []
        for image in images {
            pages.append(await scan(image, modelReader: modelReader))
        }
        return pages
    }

    // the camera reading, then the ai reading checked against it
    static func scan(_ photo: UIImage, modelReader: PageModelReader? = nil) async -> ScannedPage {
        var page = await scan(photo)
        // clear misreads in dates and doses are fixed and told to the patient, anything unclear is only shown
        defer {
            let repaired = NumberRepair.repair(page.text)
            page.text = repaired.text
            page.notes += NumberRepair.notes(repaired.changes) + ReadAgreement.smudgeNotes(repaired.text)
        }
        guard let modelReader, let image = page.image else { return page }
        do {
            let transcript = try await modelReader.transcribe(image)
            guard transcript.contains(where: { $0.isLetter }) else { throw PlanReaderError.couldNotRead }
            let combined = ReadAgreement.combine(model: transcript, camera: page.lines.map(\.text), reader: modelReader.name)
            page.text = combined.text
            page.notes += combined.notes
            log.info("\(modelReader.name) read the page with \(combined.notes.count) notes")
        } catch {
            // said to the patient, the camera reading is on this phone too so nothing else is sent anywhere
            log.error("\(modelReader.name) could not read a page: \(String(describing: type(of: error)))")
            page.notes.append("\(modelReader.name) couldn\u{2019}t read this page, so the iPhone camera reading was used.")
        }
        return page
    }

    // cut out the page, read it, then read it again with shadows lifted
    // the better read is kept and any number the two reads disagree on becomes a note
    static func scan(_ photo: UIImage) async -> ScannedPage {
        guard let raw = upright(photo).cgImage else { return ScannedPage(text: "") }
        let flat = await PagePreparer.flattened(raw)
        let picture = UIImage(cgImage: flat)
        var page = await scanDocument(flat, image: picture)

        if let even = PagePreparer.evenLight(flat) {
            let second = await scanDocument(even, image: picture)
            log.info("Second read with even light: \(Int(page.score)) vs \(Int(second.score))")
            let keepSecond = second.score > page.score * 1.03
            let other = keepSecond ? page : second
            if keepSecond { page = second }
            let mismatches = ReadAgreement.numberMismatches(kept: page.lines.map(\.text), other: other.lines.map(\.text))
            page.notes = ReadAgreement.notes(mismatches, reader: "The camera")
        }
        if page.text.filter({ $0.isLetter || $0.isNumber }).isEmpty {
            page = await scanLines(picture)
        }
        return page
    }

    // vision document request for the words, tables and list items, laid out by PageStructure
    static func scanDocument(_ cgImage: CGImage, image: UIImage?) async -> ScannedPage {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.textRecognitionOptions.customWords = MedicalWords.visionWords

        do {
            guard let document = try await request.perform(on: cgImage).first?.document else {
                return ScannedPage(text: "", image: image)
            }
            let observations = document.text.lines
            let lines: [ScannedLine] = observations.compactMap { observation in
                guard let best = observation.topCandidates(1).first else { return nil }
                return ScannedLine(text: best.string, box: topLeft(observation.boundingBox.cgRect), confidence: best.confidence)
            }
            // the tilt of the photo from the top corners of each line, measured from the top
            let tilt = PageStructure.slope(of: observations.map {
                (CGPoint(x: $0.topLeft.x, y: 1 - $0.topLeft.y), CGPoint(x: $0.topRight.x, y: 1 - $0.topRight.y))
            }) ?? 0
            // tables keep their cells, list items tell PageStructure where a faint bullet starts an item
            let tables = document.tables.map { table in
                PageStructure.Table(box: box(table), rows: table.rows.map { $0.map { $0.content.text.transcript } })
            }
            let listStarts = document.lists.flatMap { list in list.items.map { box($0.content) } }
            let pieces = PageStructure.leveled(lines.map { PageStructure.Piece(text: $0.text, box: $0.box) }, slope: tilt)
            let text = PageStructure.text(from: pieces,
                                          tables: tables.map { PageStructure.Table(box: PageStructure.leveled($0.box, slope: tilt), rows: $0.rows) },
                                          listStarts: listStarts.map { PageStructure.leveled($0, slope: tilt) })
            return ScannedPage(text: text, lines: lines, barcodes: await findBarcodes(cgImage), image: image)
        } catch {
            log.error("Could not read document: \(error.localizedDescription)")
            return ScannedPage(text: "", image: image)
        }
    }

    // the plain line reader, used when the document reader finds nothing
    static func scanLines(_ photo: UIImage) async -> ScannedPage {
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
                guard let best = observation.topCandidates(1).first else { return nil }
                return ScannedLine(text: best.string, box: topLeft(observation.boundingBox.cgRect), confidence: best.confidence)
            }
            return ScannedPage(text: layout(lines), lines: lines, barcodes: await findBarcodes(cgImage), image: image)
        } catch {
            log.error("Could not read page: \(error.localizedDescription)")
            return ScannedPage(text: "", image: image)
        }
    }

    // MARK: - Layout

    // the words back in reading order with columns lists and wrapped lines rebuilt
    static func layout(_ lines: [ScannedLine]) -> String {
        PageStructure.text(from: lines.map { PageStructure.Piece(text: $0.text, box: $0.box) })
    }

    // MARK: - Boxes

    // vision measures from the bottom left
    private static func topLeft(_ box: CGRect) -> CGRect {
        CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }

    // vision's boxes start at the bottom left, the app's at the top left
    private static func box(_ region: some BoundingRegionProviding) -> CGRect {
        topLeft(region.boundingRegion.normalizedPath.boundingBox)
    }

    // barcodes on patient stickers carry the record number so they are blacked out too
    private static func findBarcodes(_ cgImage: CGImage) async -> [CGRect] {
        guard let found = try? await DetectBarcodesRequest().perform(on: cgImage) else { return [] }
        return found.map { topLeft($0.boundingBox.cgRect) }
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
