//
//  ContactActions.swift
//  Remedy
//
//  adds, changes and removes the people on the help screen
//

import Foundation
import SwiftData

// adds, changes and removes the people on the help screen
enum ContactActions {

    // most people the help screen lists
    static let helpLimit = 3

    static func add(name: String, phone: String, detail: String = "", to plan: CarePlan, in context: ModelContext) {
        let contact = CareContact(name: name, detail: detail, phone: phone, role: .family)
        contact.plan = plan
        context.insert(contact)
        plan.contacts.append(contact)
        context.saveNow()
    }

    static func update(_ contact: CareContact, name: String, phone: String, detail: String? = nil,
                       in context: ModelContext) {
        contact.name = name
        contact.phone = phone
        if let detail { contact.detail = detail }
        context.saveNow()
    }

    static func remove(_ contact: CareContact, in context: ModelContext) {
        context.delete(contact)
        context.saveNow()
    }
}
