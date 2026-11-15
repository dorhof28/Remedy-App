//
//  EditDrafts.swift
//  Remedy
//
//  what the edit forms hold, checked before anything is saved
//

import Foundation

// MARK: - Medicine

// the medicine edit form's fields, saved only when the patient taps save
nonisolated struct MedicineDraft: Equatable {
    var name = ""
    var amount = ""
    var notes = ""
    // what it is for, an as-needed medicine's only-if line or an every-day one's reason
    var purpose = ""
    var action: MedicineAction = .take
    // minutes since midnight
    var times: [Int] = []
    // plan days (0 = surgery day), nil = no date
    var startDay: Int?
    var endDay: Int?
    // typed digits for as needed medicines
    var maxPerDay = ""
    var minHours = ""

    // plain sentences the form shows, empty means ok to save
    var problems: [String] {
        var list: [String] = []
        if trimmedName.isEmpty { list.append("Add the medicine name.") }
        if usesTimes && MedicineDraft.cleanTimes(times).isEmpty { list.append("Add at least one time each day.") }
        if let start = startDay, let end = endDay, end < start {
            list.append("The last day is before the first day.")
        }
        if !maxPerDay.isEmpty, EditText.number(maxPerDay).map({ !(1...24).contains($0) }) ?? true {
            list.append("Most a day must be a number from 1 to 24.")
        }
        if !minHours.isEmpty, EditText.number(minHours).map({ !(1...48).contains($0) }) ?? true {
            list.append("Hours between must be a number from 1 to 48.")
        }
        return list
    }

    var canSave: Bool { problems.isEmpty }
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    // only as needed medicines have no set times
    var usesTimes: Bool { action == .take }

    // sorted with no repeats
    static func cleanTimes(_ times: [Int]) -> [Int] {
        Array(Set(times.map { min(max($0, 0), 24 * 60 - 1) })).sorted()
    }

    // a new time one hour after the last, or 8 AM
    static func nextTime(after times: [Int]) -> Int {
        guard let last = times.max() else { return 8 * 60 }
        var next = (last + 60) % (24 * 60)
        while times.contains(next) { next = (next + 30) % (24 * 60) }
        return next
    }
}

// MARK: - Visit

// the visit edit form's fields
nonisolated struct AppointmentDraft: Equatable {
    var title = ""
    var doctor = ""
    var place = ""
    var phone = ""
    var notes = ""
    var date = Date()

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var problems: [String] {
        trimmedTitle.isEmpty ? ["Add what the visit is."] : []
    }

    var canSave: Bool { problems.isEmpty }
}

// MARK: - To do

// the to-do edit form's fields
nonisolated struct TaskDraft: Equatable {
    var title = ""
    var dueDay: Int?

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedTitle.isEmpty }
}

// MARK: - Text helpers

// cleans typed text before it is saved
nonisolated enum EditText {
    // digits only, "(555) 010-0123" becomes "5550100123"
    static func digits(_ text: String) -> String {
        text.filter { $0.isNumber && $0.isASCII }
    }

    // the return key in a box that grows: cuts the line break out and says the person meant to send
    static func submitted(_ text: String) -> (text: String, didSubmit: Bool) {
        guard text.contains(where: \.isNewline) else { return (text, false) }
        let clean = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return (clean.trimmingCharacters(in: .whitespaces), true)
    }

    // a whole number from typed text, nil when it isn't one
    static func number(_ text: String) -> Int? {
        let clean = text.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, clean.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(clean)
    }
}

// MARK: - Focus order (return key goes to the next field)

// which form field the return key moves to
nonisolated enum FocusOrder {
    // the field after this one, nil after the last
    static func next<Field: Equatable>(after field: Field, in order: [Field]) -> Field? {
        guard let index = order.firstIndex(of: field), index + 1 < order.count else { return nil }
        return order[index + 1]
    }

    static func isLast<Field: Equatable>(_ field: Field, in order: [Field]) -> Bool {
        order.last == field
    }
}
