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
    let phoneText: String       // "(555) 201-4480"
    let phoneURL: URL?
    let symbol: String

    var id: PersistentIdentifier { contact.persistentModelID }
    var spokenLabel: String { "\(name), \(detail), \(phoneText)" }
}

struct HelpViewModel {

    let plan: CarePlan?

    // MARK: - Words

    let title = "Get help"
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
                           phoneText: DayMath.phoneText(contact.phone),
                           phoneURL: contact.phone.isEmpty ? nil : DayMath.phoneURL(contact.phone),
                           symbol: symbol(for: contact.role))
            }
    }
    var showsContacts: Bool { !contactRows.isEmpty }

    private func symbol(for role: ContactRole) -> String {
        switch role {
        case .careTeam: return "stethoscope"
        case .pharmacy: return "cross.vial.fill"
        case .family: return "person.2.fill"
        }
    }
}
