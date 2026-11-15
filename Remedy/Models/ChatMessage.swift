//
//  ChatMessage.swift
//  Remedy
//
//  one message on the ask screen
//

import Foundation
import SwiftData

// one question or answer in ask, kept so the chat is there next time
@Model
final class ChatMessage {

    var text: String = ""

    // true if the patient asked it
    var isFromPatient: Bool = true

    var createdAt: Date = Date()

    var quote: String = ""

    // true for call your doctor / 911 answers
    var isWarning: Bool = false

    // where the quote is from
    var quoteSource: String = ""

    // number for the Call button
    var callPhone: String = ""

    // AnswerKind raw value fromPapers / notOnPapers / callSurgeon / call911 / whichOne
    var kindRaw: String = ""

    // whichOne: the medicine names to tap
    var choices: [String] = []

    init(text: String, isFromPatient: Bool, quote: String = "", isWarning: Bool = false) {
        self.text = text
        self.isFromPatient = isFromPatient
        self.quote = quote
        self.isWarning = isWarning
    }
}
