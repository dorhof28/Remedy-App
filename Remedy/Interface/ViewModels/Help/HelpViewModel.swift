//
//  HelpViewModel.swift
//  Remedy
//
//  get help for both looks
//

import Foundation
import SwiftData

// one person or place to call
struct ContactRow: Identifiable {
    let contact: CareContact
    let name: String            // "Surgeon's office"
    let detail: String          // "Questions about your surgery"
    let phoneText: String       // "(201) 555-0142"
    let phoneURL: URL?
    let symbol: String
    // text and email only when the contact has them
    var messageURL: URL? = nil
    var emailURL: URL? = nil

    var id: PersistentIdentifier { contact.persistentModelID }
    var spokenLabel: String { "\(name), \(detail), \(phoneText)" }
}

// the help screen: 911, the care team's numbers and when to call
struct HelpViewModel {

    let plan: CarePlan?

    // MARK: - Words

    let title = "Help"
    let doneTitle = "Done"
    let emergencyTitle = "Call 911"
    let emergencyDetail = "Trouble breathing, chest pain, fainting, or anything that feels like an emergency."
    let emergencyURL = DayMath.phoneURL("911")
    let warningTitle = "Call your surgeon now if"
    let warningFootnote = "Common warning signs after surgery. Your own papers may list others."
    let contactsTitle = "Your care team"
    let noContactsText = "No phone numbers yet. They\u{2019}re added when you scan your papers."
    let callTitle = "Call"

    // common warning signs after surgery
    let warningSigns = [
        "Fever over 101\u{00B0}F (38.3\u{00B0}C)",
        "Bleeding that soaks through the bandage",
        "Pain, swelling or warmth in your calf",
        "The cut is red, hot, or leaking",
        "Pain that your medicine doesn\u{2019}t help",
        "Throwing up and can\u{2019}t keep medicine down",
    ]

    // MARK: - Contacts (care team first, then pharmacy, then family)

    var contactRows: [ContactRow] {
        let order: [ContactRole] = [.careTeam, .pharmacy, .family]
        return (plan?.contacts ?? [])
            .sorted { (order.firstIndex(of: $0.role) ?? 9) < (order.firstIndex(of: $1.role) ?? 9) }
            .map { contact in
                ContactRow(contact: contact, name: contact.name, detail: contact.detail,
                           phoneText: PhoneFormat.text(contact.phone),
                           phoneURL: contact.phone.isEmpty ? nil : DayMath.phoneURL(contact.phone),
                           symbol: symbol(for: contact),
                           messageURL: ContactLinks.messageURL(phone: contact.phone),
                           emailURL: ContactLinks.emailURL(for: contact))
            }
    }
    var showsContacts: Bool { !contactRows.isEmpty }

    // a heart clinic and a surgery team should not look the same
    private func symbol(for contact: CareContact) -> String {
        let name = contact.name.lowercased()
        if contact.role == .careTeam {
            if name.contains("heart") || name.contains("cardio") { return "heart.fill" }
            if name.contains("testing") || name.contains("lab") || name.contains("admission") { return "list.clipboard.fill" }
            if name.contains("rehab") || name.contains("therapy") { return "figure.walk" }
        }
        return symbol(for: contact.role)
    }

    private func symbol(for role: ContactRole) -> String {
        switch role {
        case .careTeam: return "stethoscope"
        case .pharmacy: return "cross.vial.fill"
        case .family: return "person.2.fill"
        }
    }
}

// MARK: - Redesigned help (screens 56 and 58)

extension HelpViewModel {
    static let callSectionTitle = "Call"
    static let editButton = "Edit"
    static let whenTitle = "When should I call?"
    static let emergencyFootnote = "Trouble breathing, chest pain, fainting, heavy bleeding."
    static let emergencyInfoRowTitle = "Emergency Info"
    static let emergencyInfoRowText = "Medical ID text and a Wallet card"
    static let contactsTitle = "Help Contacts"
    static let chooseContact = "Choose From Contacts"
    static let typeContact = "Type a Name and Number"
    static let contactsFooter2 = "Each contact has Call and Message on the Help screen."
    static let messageTitle = "Message"
    static let nameLabel = "Name"
    static let newContactTitle = "New Contact"
    static let contactTitle = "Contact"
    static let roleLabel = "Role"
    static let phoneLabel = "Phone"
    static func deleteContact(_ name: String) -> String { name.isEmpty ? "Delete Contact" : "Delete \(name)" }
    static func deleteAsk(_ name: String) -> String { name.isEmpty ? "Delete this contact?" : "Delete \(name)?" }

    // the three people on the help screen
    var helpRows: [ContactRow] { Array(contactRows.prefix(ContactActions.helpLimit)) }

    // "Lakeside Orthopedics · (555) 010-0142"
    func subtitle(_ row: ContactRow) -> String {
        guard row.phoneURL != nil else { return "No number on your papers" }
        return [row.detail, row.phoneText].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    // "(555) 010-0142 · from your papers"
    func editSubtitle(_ row: ContactRow) -> String {
        let fromPapers = row.contact.role != .family
        return fromPapers ? "\(row.phoneText) \u{00B7} from your papers" : row.phoneText
    }

    // "3 of 3. To change one, tap it. To remove one, tap it, then Remove Contact."
    var contactsFooter: String {
        "\(min(contactRows.count, ContactActions.helpLimit)) of \(ContactActions.helpLimit). To change one, tap it. To remove one, tap it, then Remove Contact."
    }

    var canAddContact: Bool { contactRows.count < ContactActions.helpLimit }

    // the surgeon signs first, 911 last, like the design
    var whenRows: [WarningSignItem] {
        let items = warningSignItems
        return items.filter { $0.tone != .stop } + items.filter { $0.tone == .stop }
    }
}
