//
//  ScanFlowViewModel+Gaps.swift
//  Remedy
//
//  what could not be found on the papers, asked on the check screens
//

import Foundation

// the add the doctor's phone question when a read found none
enum PhoneGapState { case notAsked, asking, added, skipped, none }

extension ScanFlowViewModel {

    var gapEyebrow: String { "Missing from your paper" }
    var phoneGapTitle: String { "Your paper has no phone number for your surgeon" }
    var phoneGapText: String { "Add it so Call buttons work. It\u{2019}s on your appointment card or the office\u{2019}s website." }
    var phoneGapFooter: String { "You can add it later in Help." }
    var phoneFieldLabel: String { "Phone" }
    var addNumberButton: String { "Add Number" }
    var skipButton: String { "Skip" }
    var skippedPhoneTask: String { "Add your surgeon\u{2019}s phone number." }

    // looks once when the check opens, the surgery date gap is asked on 13 and Today
    func startCheckGaps() {
        guard phoneGap == .notAsked else { return }
        phoneGap = readGaps.contains { $0.kind == .doctorPhone } ? .asking : .none
    }

    var isAskingPhoneGap: Bool { phoneGap == .asking }

    // the gap counts as the first item, "Item 1 of 8"
    private var gapItems: Int { phoneGap == .none || phoneGap == .notAsked ? 0 : 1 }

    var checkProgressText: String {
        let total = cards.count + gapItems
        let at = isAskingPhoneGap ? 1 : min(cardIndex + 1, cards.count) + gapItems
        return "Item \(at) of \(total)"
    }

    var checkProgressValue: Double { Double(isAskingPhoneGap ? 1 : cardIndex + 1 + gapItems) }
    var checkProgressTotal: Double { Double(max(cards.count + gapItems, 1)) }

    func savePhoneGap() {
        guard addDoctorPhone(gapPhone) else { return }
        Motion.run { phoneGap = .added }
    }

    func skipPhoneGap() {
        Motion.run { phoneGap = .skipped }
    }

    // a skipped number becomes a to-do once every item is checked, so the count above stays right
    func addSkippedPhoneTask() {
        guard phoneGap == .skipped, draft != nil,
              !(draft?.tasks.contains { $0.title == skippedPhoneTask } ?? false) else { return }
        draft?.tasks.append(.confirmedTodo(skippedPhoneTask))
    }

    // 88 words, the question waits for an answer before This Is Right
    var questionEyebrow: String { "Your paper doesn\u{2019}t say" }
    var answerFirstNote: String { "Answer the question first." }
    var changeAnswerButton: String { "Change" }
    var amPmText: String { "Was that dose in the morning or the evening?" }
    var morningButton: String { "Morning (AM)" }
    var eveningButton: String { "Evening (PM)" }

    var waitsForAnswer: Bool {
        if let question = amPmQuestion, question.picked == nil { return true }
        if let question = hospitalDoseQuestion(), question.answer == nil { return true }
        return false
    }

    // forgets the last given time when the am or pm question is open
    func clearLastGiven() {
        guard amPmQuestion != nil, let i = currentMedicineIndex else { return }
        draft?.medicines[i].lastGivenPick = nil
    }

    // drops the hospital dose time from the current medicine
    func clearHospitalDose() {
        guard let i = currentMedicineIndex else { return }
        draft?.medicines[i].hospitalDoseAnswer = nil
    }

    // what the reader left out, each one can be fixed from the results
    var readGaps: [ReadGap] {
        guard let draft else { return [] }
        let phone = draft.contacts.contains { !$0.phone.isEmpty } || draft.appointments.contains { !$0.phone.isEmpty }
        return ReadGaps.find(hasSurgeryDate: draft.surgeryDate != nil || planHasSurgeryDate,
                             medicines: draft.medicines.count, instructions: draft.rules.count + draft.tasks.count,
                             visits: draft.appointments.count, hasPhone: phone, paper: draft.paper)
    }

    // the day the patient says the operation is, kept as a pick so the finish screen does not ask again
    func setSurgeryDate(_ date: Date) {
        surgeryDate = date
        hasPickedDate = true
        draft?.surgeryDate = date
    }

    // true when the text has enough digits to be a phone number
    static func isPhone(_ text: String) -> Bool { text.filter(\.isNumber).count >= 7 }

    // a phone number typed from the results, saved as a contact with the doctor on the paper
    @discardableResult
    func addDoctorPhone(_ text: String) -> Bool {
        let phone = text.trimmed
        guard Self.isPhone(phone), draft != nil else { return false }
        draft?.contacts.append(DraftContact(name: foundDoctor ?? "My care team", phone: phone))
        gapPhone = ""
        return true
    }
}
