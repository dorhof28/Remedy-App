//
//  CareContact.swift
//  Remedy
//
//  a phone number for the contact screen
//

import Foundation
import SwiftData

@Model
final class CareContact {

    var name: String = ""
    var detail: String = ""
    var phone: String = ""
    var roleRaw: String = ContactRole.careTeam.rawValue

    // the plan it belongs to
    var plan: CarePlan?

    init(name: String, detail: String, phone: String, role: ContactRole) {
        self.name = name
        self.detail = detail
        self.phone = phone
        self.roleRaw = role.rawValue
    }

    var role: ContactRole {
        get { ContactRole(rawValue: roleRaw) ?? .careTeam }
        set { roleRaw = newValue.rawValue }
    }
}
