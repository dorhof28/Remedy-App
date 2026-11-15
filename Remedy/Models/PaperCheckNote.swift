//
//  PaperCheckNote.swift
//  Remedy
//
//  what the office said about two papers that disagree
//

import Foundation
import SwiftData

// what the office said about a red card, and which paper to follow
@Model
final class PaperCheckNote {

    // Finding.key, medicine plus both paper ids
    var findingKey: String = ""
    // the paper the office said to follow
    var chosenPaperID: UUID?
    var officeSaid: String = ""
    var whoSaid: String = ""
    var date: Date = Date()

    init(findingKey: String, chosenPaperID: UUID, officeSaid: String, whoSaid: String, date: Date = Date()) {
        self.findingKey = findingKey
        self.chosenPaperID = chosenPaperID
        self.officeSaid = officeSaid
        self.whoSaid = whoSaid
        self.date = date
    }
}
