//
//  FamilySheetPDF.swift
//  Remedy
//
//  draws the family page into a pdf
//

import SwiftUI

// draws a family sheet into a pdf file
enum FamilySheetPDF {

    // the PDF's address or nil if it couldn't be drawn
    static func make(_ sheet: FamilySheet, named fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var page = CGRect(origin: .zero, size: FamilySheetPage.size)
        guard let pdf = CGContext(url as CFURL, mediaBox: &page, nil) else { return nil }
        var didDraw = false

        // every page, long lists carry on over more pages
        for sheet in FamilySheetPaginator.pages(for: sheet) {
            let renderer = ImageRenderer(content: FamilySheetPage(sheet: sheet))
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
                didDraw = true
            }
        }
        pdf.closePDF()
        return didDraw ? url : nil
    }

    // a letter page with one cut out card at the top
    static func makeWalletCard(_ sheet: FamilySheet, named fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var page = CGRect(origin: .zero, size: FamilySheetPage.size)
        guard let pdf = CGContext(url as CFURL, mediaBox: &page, nil) else { return nil }
        var didDraw = false
        let renderer = ImageRenderer(content: WalletCardPage(sheet: sheet))
        renderer.render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            didDraw = true
        }
        pdf.closePDF()
        return didDraw ? url : nil
    }
}

// the wallet card on a page, dashed box to cut along
struct WalletCardPage: View {
    let sheet: FamilySheet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sheet.title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.remedyTeal)
            ForEach(sheet.cover) { line in
                Text("\(line.title): \(line.detail)")
                    .font(.system(size: 13, weight: .semibold))
            }
            ForEach(sheet.left) { block in
                Text(block.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                    .padding(.top, 4)
                ForEach(block.lines) { line in
                    Text("\u{2022} \(line.title)").font(.system(size: 12.5))
                }
            }
            Text(sheet.footer)
                .font(.system(size: 8))
                .foregroundStyle(.gray)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(width: 400, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .padding(32)
        .frame(width: FamilySheetPage.size.width, height: FamilySheetPage.size.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }
}
