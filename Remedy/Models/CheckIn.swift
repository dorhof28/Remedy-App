//
//  CheckIn.swift
//  Remedy
//
//  one daily recovery check in
//

import Foundation
import SwiftData

// the patient's pain, signs and note for one plan day
@Model
final class CheckIn {

    // plan day it was for
    var day: Int = 0
    var pain: Int = 0
    var signs: [String] = []
    var note: String = ""
    var createdAt: Date = Date()
    // set when a saved check-in is changed, the first time stays in createdAt
    var editedAt: Date?

    init(day: Int, pain: Int, signs: [String] = [], note: String = "") {
        self.day = day
        self.pain = pain
        self.signs = signs
        self.note = note
    }
}
