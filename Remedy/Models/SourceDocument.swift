//
//  SourceDocument.swift
//  Remedy
//
//  scanned page
//

import Foundation
import SwiftData

@Model
final class SourceDocument {

    var pageNumber: Int = 1

    // which paper this page is from
    var paperRaw: String = PaperKind.afterSurgery.rawValue

    // the page's text after redaction
    var redactedText: String = ""

    var scannedAt: Date = Date()

    // which plan its from
    var plan: CarePlan?

    init(pageNumber: Int, paper: PaperKind, redactedText: String) {
        self.pageNumber = pageNumber
        self.paperRaw = paper.rawValue
        self.redactedText = redactedText
    }

    var paper: PaperKind {
        get { PaperKind(rawValue: paperRaw) ?? .afterSurgery }
        set { paperRaw = newValue.rawValue }
    }
}
