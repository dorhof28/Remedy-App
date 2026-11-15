//
//  ChatActions.swift
//  Remedy
//
//  saves chat messages
//

import Foundation
import SwiftData

// saves and clears the ask chat
enum ChatActions {

    // save
    @discardableResult
    static func add(_ text: String,
                    isFromPatient: Bool,
                    quote: String = "",
                    isWarning: Bool = false,
                    in context: ModelContext) -> ChatMessage {
        let message = ChatMessage(text: text, isFromPatient: isFromPatient, quote: quote, isWarning: isWarning)
        context.insert(message)
        context.saveNow()
        return message
    }

    // save an answer from AskAnswers
    @discardableResult
    static func addAnswer(_ answer: AskAnswer, in context: ModelContext) -> ChatMessage {
        let isWarning = answer.kind == .call911 || answer.kind == .callSurgeon
        let message = ChatMessage(text: answer.text, isFromPatient: false, quote: answer.quote, isWarning: isWarning)
        message.quoteSource = answer.quoteSource
        message.callPhone = answer.phone
        message.kindRaw = answer.kind.rawValue
        message.choices = answer.choices
        context.insert(message)
        context.saveNow()
        return message
    }

    // delete @nikhil implement this in settings
    static func deleteAll(in context: ModelContext) {
        do {
            try context.delete(model: ChatMessage.self)
        } catch {
            print("Remedy: could not clear chat: \(error)")
        }
        context.saveNow()
    }
}
