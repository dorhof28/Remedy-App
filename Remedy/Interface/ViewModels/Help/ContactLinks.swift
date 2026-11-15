//
//  ContactLinks.swift
//  Remedy
//
//  text and email links for a care contact, only when the contact has them
//

import Foundation

// call, text and email links for a contact
enum ContactLinks {

    // text message link from the phone number
    static func messageURL(phone: String) -> URL? {
        let cleaned = phone.filter { $0.isNumber || $0 == "+" }
        guard cleaned.count >= 7 else { return nil }
        return URL(string: "sms:" + cleaned)
    }

    // email typed in or found in the contact's detail line
    static func email(for contact: CareContact) -> String? {
        let typed = contact.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if isEmail(typed) { return typed }
        return contact.detail.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "()<>.")) }
            .first(where: { isEmail($0) })
    }

    static func emailURL(for contact: CareContact) -> URL? {
        email(for: contact).flatMap { URL(string: "mailto:" + $0) }
    }

    // one @ with text each side and a dot in the domain
    static func isEmail(_ text: String) -> Bool {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !text.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}
