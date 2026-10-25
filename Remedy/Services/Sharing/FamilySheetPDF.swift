//
//  FamilySheetPDF.swift
//  Remedy
//
//  draws the family page into a pdf
//

import SwiftUI

enum FamilySheetPDF {

    // the PDF's address or nil if it couldn't be drawn
    static func make(_ sheet: FamilySheet, named fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let renderer = ImageRenderer(content: FamilySheetPage(sheet: sheet))
        var didDraw = false

        renderer.render { _, draw in
            var page = CGRect(origin: .zero, size: FamilySheetPage.size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &page, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            didDraw = true
        }
        return didDraw ? url : nil
    }
}
