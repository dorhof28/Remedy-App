//
//  MistakeReport.swift
//  Remedy
//
//  a small report about one wrong item that the patient can share
//

import Foundation

// a short report about one wrong item to send to the care team
struct MistakeReport: Equatable {

    let item: String
    let quote: String
    let pageText: String
    let reader: String
    let appVersion: String

    // every part goes through the redactor so names and record numbers never leave
    // names nil uses the names saved in the scan screen
    init(item: String, quote: String, pageText: String, reader: String,
         appVersion: String = MistakeReport.currentVersion, names: [String]? = nil) {
        let typed = names ?? PatientNames.saved
        self.item = MistakeReport.clean(item, typed)
        self.quote = MistakeReport.clean(quote, typed)
        self.pageText = MistakeReport.clean(pageText, typed)
        self.reader = reader
        self.appVersion = appVersion
    }

    // the message the patient sends
    var text: String {
        [
            "Remedy mistake report",
            "",
            "Item as read:",
            item,
            "",
            "Line from the paper:",
            quote.isEmpty ? "(none)" : quote,
            "",
            "Page text (personal details hidden):",
            pageText.isEmpty ? "(not available)" : pageText,
            "",
            "Read by: \(reader.isEmpty ? "unknown" : reader)",
            "App version: \(appVersion)",
        ].joined(separator: "\n")
    }

    var subject: String { "Remedy mistake report" }

    static var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // also hides the typed names in the short parts that have no label
    private static func clean(_ text: String, _ names: [String]) -> String {
        let page = Redactor.redact(text, names: names)
        return page.text
    }
}
