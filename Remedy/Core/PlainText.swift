//
//  PlainText.swift
//  Remedy
//
//  small helpers for readable text
//

import Foundation

enum PlainText {

    
    // a b and c
    static func list(_ items: [String]) -> String {
        if items.isEmpty { return "" }
        if items.count == 1 { return items[0] }
        let allButLast = items.dropLast().joined(separator: ", ")
        return allButLast + " and " + (items.last ?? "")
    }

    // 1 tablet or 2 tablets
    static func count(_ number: Int, _ word: String) -> String {
        number == 1 ? "1 \(word)" : "\(number) \(word)s"
    }

    // which paper and page
    static func source(paper: PaperKind, page: Int?) -> String {
        let name = paper == .beforeSurgery ? "Before-surgery papers" : "After-surgery papers"
        guard let page = page else { return name }
        return "\(name), page \(page)"
    }

    // lowercases the first letter
    static func lowerFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).lowercased() + String(text.dropFirst())
    }
}
