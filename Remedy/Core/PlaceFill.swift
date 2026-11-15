//
//  PlaceFill.swift
//  Remedy
//
//  turns a picked map suggestion into the hospital name and address, no MapKit here
//

import Foundation

// a hospital or office name and address picked from the address suggestions
nonisolated struct PlaceFill: Equatable {
    let name: String
    let address: String

    // name from the place, address from the full formatted one, else the suggestion's own two lines
    static func make(suggestionTitle: String, suggestionSubtitle: String,
                     itemName: String?, fullAddress: String?) -> PlaceFill {
        let title = suggestionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = suggestionSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = (itemName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let full = oneLine(fullAddress ?? "")

        // a street picked with no place behind it has no name to give
        let name = item.isEmpty ? (looksLikeStreet(title) ? "" : title) : item
        var address = full
        if address.isEmpty {
            // a street suggestion has the street as its title, a place has it in the subtitle
            address = subtitle.isEmpty ? "" : (looksLikeStreet(title) ? "\(title), \(subtitle)" : subtitle)
        }
        return PlaceFill(name: name, address: address)
    }

    // "123 Main St" starts with a number
    static func looksLikeStreet(_ text: String) -> Bool {
        guard let first = text.trimmingCharacters(in: .whitespaces).first else { return false }
        return first.isNumber
    }

    // MapKit separates lines with newlines
    static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // a suggestion whose subtitle is a search hint rather than a place is not worth showing
    static func isUsable(title: String, subtitle: String) -> Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !subtitle.hasPrefix("Search Nearby")
    }
}
