//
//  EmergencyInfoViewModel.swift
//  Remedy
//
//  text for Medical ID and a wallet card for both looks
//

import Foundation

// the medical id text and wallet card built from the plan
struct EmergencyInfoViewModel {

    let plan: CarePlan?
    let now: Date

    // MARK: - Words

    let title = "Emergency info"
    let intro = "Apps can\u{2019}t write to Medical ID, so Remedy writes the words for you. Copy them, then paste them into Health."
    let walletTitle = "Wallet card"
    let walletFailedText = "Couldn\u{2019}t make the card. Try again."
    let walletFileName = "Remedy wallet card.pdf"
    let noPlanText = "Scan your papers first. Then this page can write your emergency info."
    let steps = [
        "Open the Health app and tap your picture, then Medical ID.",
        "Tap Edit and paste the text into Medical Notes.",
        "Turn on Show When Locked and tap Done.",
    ]

    var hasPlan: Bool { plan != nil }

    // MARK: - The text

    // medicines the plan says to take today (not stopped, not finished, not unconfirmed)
    var medicineNames: [String] {
        guard let plan else { return [] }
        let day = plan.surgeryDate.map { DayMath.dayOffset(of: now, from: $0) }
        return plan.medicines
            .filter { medicine in
                guard medicine.isConfirmed, !medicine.isGroup else { return false }
                guard medicine.action == .take || medicine.action == .takeAsNeeded else { return false }
                guard let day else { return true }
                return DoseSchedule.isActive(medicine, on: day)
            }
            .sorted { $0.createdAt < $1.createdAt }
            .map { medicine in
                let dose = [MedicineText.fullName(medicine), medicine.amount].filter { !$0.isEmpty }.joined(separator: " ")
                return medicine.action == .takeAsNeeded ? "\(dose) (only when needed)" : dose
            }
    }

    // the surgeon's office first
    var surgeonLine: String? {
        guard let contact = HelpViewModel(plan: plan).contactRows.first(where: { $0.contact.role == .careTeam && !$0.contact.phone.isEmpty })
        else { return nil }
        return "\(contact.name) \(contact.phoneText)"
    }

    var surgeryLine: String? {
        guard let plan, !plan.procedure.isEmpty else { return nil }
        guard let date = plan.surgeryDate else { return "Recent surgery: \(plan.procedure)" }
        return "Recent surgery: \(plan.procedure), \(DayMath.longDate(date))"
    }

    // lines to paste into Medical ID
    var text: String {
        var lines: [String] = []
        if let surgeryLine { lines.append(surgeryLine) }
        let names = medicineNames
        if !names.isEmpty { lines.append("Medicines now: " + names.joined(separator: "; ")) }
        if let surgeonLine { lines.append("Surgeon: \(surgeonLine)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - The emergency sheet

    static let sheetTitle = "Emergency"
    let medicinesLabel = "Medicines now"
    let warningTitle = "Call your surgeon now if"
    let allergiesLabel = "Allergies"
    // allergies are not saved from papers yet so say so plainly
    let allergiesText = "None on your papers. Tell the team if you have any."
    let noMedicinesText = "None right now"
    let emergencyURL = DayMath.phoneURL("911")

    // one labeled fact on the card
    struct Fact: Identifiable, Equatable {
        let label: String
        let value: String
        let symbol: String
        var id: String { label }
    }

    var surgeon: ContactRow? {
        HelpViewModel(plan: plan).contactRows.first { $0.contact.role == .careTeam && !$0.contact.phone.isEmpty }
    }

    var warningSigns: [String] { HelpViewModel(plan: plan).warningSigns }

    // short labeled lines, only what we know, medicines last because the list can be long
    var facts: [Fact] {
        guard let plan else { return [] }
        var list: [Fact] = []
        if !plan.procedure.isEmpty {
            let when = plan.surgeryDate.map { ", " + DayMath.longDate($0) } ?? ""
            list.append(Fact(label: "Surgery", value: plan.procedure + when, symbol: "cross.case.fill"))
        }
        if let surgeon {
            list.append(Fact(label: "Doctor", value: "\(surgeon.name)\n\(surgeon.phoneText)", symbol: "stethoscope"))
        }
        list.append(Fact(label: allergiesLabel, value: allergiesText, symbol: "allergens"))
        let names = medicineNames
        list.append(Fact(label: medicinesLabel, value: names.isEmpty ? noMedicinesText : names.joined(separator: "\n"),
                         symbol: "pills.fill"))
        return list
    }

    // MARK: - Wallet card

    var cardSheet: FamilySheet {
        var cover: [FamilyLine] = []
        if let plan, !plan.procedure.isEmpty {
            cover.append(FamilyLine(title: "Surgery", detail: plan.procedure + (plan.surgeryDate.map { ", " + DayMath.longDate($0) } ?? "")))
        }
        if let surgeonLine { cover.append(FamilyLine(title: "Surgeon", detail: surgeonLine)) }
        let medicines = FamilyBlock(title: "Medicines now", symbol: "pills.fill", tone: .info,
                                    lines: medicineNames.map { FamilyLine(title: $0, detail: "") }, moreText: "")
        return FamilySheet(title: "Emergency info", subtitle: "", madeOn: "Made \(DayMath.shortDate(AppClock.now())).",
                           left: [medicines], right: [],
                           footer: "From the papers the care team gave. Not medical advice. In an emergency, call 911.",
                           cover: cover)
    }

    func makeCardPDF() -> URL? {
        FamilySheetPDF.makeWalletCard(cardSheet, named: walletFileName)
    }
}

// MARK: - Emergency info page (screen 57)

extension EmergencyInfoViewModel {
    static let pageTitle = "Emergency Info"
    static let eyebrow = "For Medical ID"
    static let footer = "Paste this into Health > Medical ID so it shows on the Lock Screen."
    static let copyButton = "Copy Text"
    static let copiedButton = "Copied"
    // a PDF card to print and keep, apps can't add their own cards to Wallet without Apple signing
    static let walletButton = "Make a Wallet Card"

    // one short paragraph a paramedic reads at a glance
    var paragraph: String {
        guard let plan else { return "" }
        var parts: [String] = []
        if !plan.procedure.isEmpty {
            let when = plan.surgeryDate.map { " on " + $0.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()) } ?? ""
            parts.append(PlainText.upperFirst(plan.procedure) + when + ".")
        }
        let names = medicineNames
        if !names.isEmpty { parts.append("Takes " + PlainText.list(names) + ".") }
        if let surgeon { parts.append("\(surgeon.name): \(surgeon.phoneText).") }
        return parts.joined(separator: " ")
    }
}
