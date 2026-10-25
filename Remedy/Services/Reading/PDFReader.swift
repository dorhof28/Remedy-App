//
//  PDFReader.swift
//  Remedy
//
//  reads the words in a pdf
//

import Foundation
import PDFKit
import UIKit

enum PDFReader {

    // more pages than this is probably the wrong file
    static let maxPages = 50

    // one string per page
    static func read(_ url: URL) async throws -> [String] {
        // files from the Files app need permission while we read them
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url), !document.isLocked else { throw PDFReaderError.cantOpen }
        guard document.pageCount > 0 else { throw PDFReaderError.empty }
        guard document.pageCount <= maxPages else { throw PDFReaderError.tooLong }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            // fewer than 20 letters = a scanned picture not real text
            if text.filter({ $0.isLetter || $0.isNumber }).count >= 20 {
                pages.append(text)
            } else {
                pages.append(await TextReader.read(image(of: page)))
            }
        }
        return pages
    }

    // draws one page as a white image about 2000 pixels on its long side
    private static func image(of page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale = 2000 / max(bounds.width, bounds.height, 1)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1                // so `size` is in pixels
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // PDF pages are drawn upside down so flip
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

// errors in plain words
enum PDFReaderError: LocalizedError {
    case cantOpen
    case empty
    case tooLong

    var errorDescription: String? {
        switch self {
        case .cantOpen: return "We couldn\u{2019}t open that PDF. If it has a password, open it and save a copy without one."
        case .empty: return "That PDF has no pages."
        case .tooLong: return "That PDF has more than \(PDFReader.maxPages) pages. Choose just your surgery papers."
        }
    }
}
