//
//  DemoPapers.swift
//  Remedy
//
//  DEMO ONLY the four HSS style sample papers bundled with the app (made by SamplePapers/demo/make-demo-pdfs.swift)
//  demo mode shows them so people can see the paper and then what Remedy made from it
//

import Foundation
import PDFKit

// the sample papers behind the HSS demo plan
enum DemoPapers {

    // one bundled paper
    struct Item: Identifiable, Hashable {
        let file: String
        let title: String
        let detail: String
        var id: String { file }

        // the pdf inside the app, nil only if the build left it out
        var url: URL? { Bundle.main.url(forResource: file, withExtension: "pdf") }
    }

    // in the order they were printed
    static let all: [Item] = [
        Item(file: "D1-internist-preop", title: "Internist pre-op visit", detail: "Oct 22 \u{00B7} Which medicines to stop and when"),
        Item(file: "D2-cardiology-letter", title: "Cardiology visit", detail: "Oct 30 \u{00B7} Eliquis 2 days, not 3"),
        Item(file: "D3-surgeon-preop", title: "Surgeon pre-op visit", detail: "Nov 2 \u{00B7} Arrival, fasting and skin prep"),
        Item(file: "D4-discharge", title: "Hospital discharge", detail: "Nov 13 \u{00B7} New medicines, rules and visits"),
    ]

    // the fake patient's name, blacked out of the page text like a real scan
    static let patientNames = ["Ruth Callahan", "Ruth", "Callahan"]

    // each page's words with the name and id numbers hidden, empty when the pdf is missing
    static func pageTexts(_ item: Item) -> [String] {
        guard let url = item.url, let document = PDFDocument(url: url) else { return [] }
        return (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            .map { Redactor.redact($0, names: patientNames).text }
    }
}
