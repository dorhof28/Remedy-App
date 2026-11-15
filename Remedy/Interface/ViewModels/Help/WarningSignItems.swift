//
//  WarningSignItems.swift
//  Remedy
//
//  a picture for each warning sign so the list reads at a glance in both looks
//

import Foundation

// one warning sign ready to draw as a tile
struct WarningSignItem: Identifiable, Equatable {
    let text: String
    let symbol: String
    let tone: Tone

    var id: String { text }
}

// picks a picture and color for each warning sign from its words
enum WarningSignPicture {

    // first match wins, the most specific words come first
    private static let pictures: [(words: [String], symbol: String)] = [
        (["chest", "heart"], "heart.fill"),
        (["breath", "breathing"], "lungs.fill"),
        (["fever", "temperature", "chills"], "thermometer.high"),
        (["bleed", "blood"], "drop.fill"),
        (["throw", "vomit", "nausea", "sick to"], "arrow.uturn.up.circle.fill"),
        (["calf", "leg"], "figure.walk"),
        (["cut", "wound", "incision", "red", "leak", "pus", "drain"], "bandage.fill"),
        (["pain", "hurt"], "bolt.fill"),
        (["faint", "dizzy", "confus"], "exclamationmark.circle.fill"),
    ]

    // sf symbol for a sign, a plain warning mark when nothing fits
    static func symbol(for sign: String) -> String {
        let text = sign.lowercased()
        for picture in pictures where picture.words.contains(where: { text.contains($0) }) {
            return picture.symbol
        }
        return "exclamationmark.triangle.fill"
    }

    // chest and breathing signs are red, the rest are a call to the surgeon
    static func tone(for sign: String) -> Tone {
        let text = sign.lowercased()
        return text.contains("chest") || text.contains("breath") ? .stop : .caution
    }

    static func items(_ signs: [String]) -> [WarningSignItem] {
        signs.map { WarningSignItem(text: $0, symbol: symbol(for: $0), tone: tone(for: $0)) }
    }
}

extension HelpViewModel {
    // the warning signs with their pictures
    var warningSignItems: [WarningSignItem] { WarningSignPicture.items(warningSigns) }
}

extension EmergencyInfoViewModel {
    var warningSignItems: [WarningSignItem] { WarningSignPicture.items(warningSigns) }
}
