//
//  ScanFlowViewModel+Confirm.swift
//  Remedy
//
//  checking each item, edit, and the hospital questions
//

import Foundation

extension ScanFlowViewModel {

    var confirmTitle: String { "Check Your Plan" }
    var looksRightButton: String { "This Is Right" }
    var editButton: String { "Fix Something" }
    // short so it fits next to Edit at one line, spoken as what it means
    var removeButton: String { "Leave It Out" }
    var removeSpoken: String { "Removes this item because it is not on your papers" }
    var backButton: String { "Back" }

    // a freshly read draft starts at its first item
    func checkItems(of plan: DraftPlan) {
        draft = plan
        cardIndex = 0
        removedIDs = []
        goToConfirm()
    }

    // starts checking items
    func goToConfirm() {
        phoneGap = .notAsked
        // start the date picker on the date the papers gave so its one tap to confirm
        if let found = draft?.surgeryDate { surgeryDate = found }
        hasPickedDate = draft?.surgeryDate != nil
        Motion.run { step = cards.isEmpty ? .finish : .confirm }
    }

    // every item that needs a yes in the order they appear on the paper
    var cards: [ConfirmCard] {
        guard let draft else { return [] }
        var result: [ConfirmCard] = []
        for (index, medicine) in draft.medicines.enumerated() { result.append(card(for: medicine, index: index)) }
        for (index, rule) in draft.rules.enumerated() { result.append(card(for: rule, index: index)) }
        for (index, task) in draft.tasks.enumerated() { result.append(card(for: task, index: index)) }
        for (index, visit) in draft.appointments.enumerated() { result.append(card(for: visit, index: index)) }
        return result
    }

    var currentCard: ConfirmCard? {
        let all = cards
        return all.indices.contains(cardIndex) ? all[cardIndex] : nil
    }

    // a report about the shown item with personal details hidden
    var mistakeReport: MistakeReport? {
        guard let card = currentCard else { return nil }
        let facts = card.facts.map { "\($0.label): \($0.value)" }
        return MistakeReport(item: ([card.eyebrow, card.title] + facts).joined(separator: "\n"), quote: card.quote,
                             pageText: redactedPages.map(\.text).joined(separator: "\n\n"),
                             reader: draft?.readBy ?? "")
    }

    var canGoBack: Bool { cardIndex > 0 }

    // item matches the paper
    func looksRight() {
        guard let card = currentCard else { return }
        setConfirmed(card.item, true)
        removedIDs.remove(card.id)
        next()
    }

    // item is wrong so drop it
    func notOnPapers() {
        guard let card = currentCard else { return }
        setConfirmed(card.item, false)
        removedIDs.insert(card.id)
        next()
    }

    // previous item
    func back() {
        guard canGoBack else { return }
        Motion.run { cardIndex -= 1 }
    }

    // the next confirm card, or the finish step after the last
    private func next() {
        Motion.run {
            if cardIndex + 1 < cards.count {
                cardIndex += 1
            } else {
                addSkippedPhoneTask()
                step = .finish
            }
        }
    }

    // current item for the edit sheet
    func editValues() -> ConfirmEdit? {
        guard let draft, let card = currentCard else { return nil }
        switch card.item {
        case .medicine(let i):
            let m = draft.medicines[i]
            return ConfirmEdit(title: m.name, hasStart: m.startDay != nil, startDay: m.startDay ?? 0,
                               hasEnd: m.endDay != nil, endDay: m.endDay ?? 0, showsDays: true)
        case .rule(let i):
            let r = draft.rules[i]
            return ConfirmEdit(title: r.title, hasStart: r.startDay != nil, startDay: r.startDay ?? 0,
                               hasEnd: r.endDay != nil, endDay: r.endDay ?? 0, showsDays: true)
        case .task(let i):
            let t = draft.tasks[i]
            return ConfirmEdit(title: t.title, hasStart: t.dueDay != nil, startDay: t.dueDay ?? 0,
                               hasEnd: false, endDay: 0, showsDays: true)
        case .appointment(let i):
            return ConfirmEdit(title: draft.appointments[i].title, hasStart: false, startDay: 0,
                               hasEnd: false, endDay: 0, showsDays: false)
        }
    }

    // saves the edit and counts it as confirmed
    func saveEdit(_ edit: ConfirmEdit) {
        guard draft != nil, let card = currentCard else { return }
        let title = edit.title.trimmingCharacters(in: .whitespaces)
        let start = edit.hasStart ? edit.startDay : nil
        let end = edit.hasEnd ? edit.endDay : nil
        switch card.item {
        case .medicine(let i):
            if !title.isEmpty { draft?.medicines[i].name = title }
            draft?.medicines[i].startDay = start
            draft?.medicines[i].endDay = end
        case .rule(let i):
            if !title.isEmpty { draft?.rules[i].title = title }
            draft?.rules[i].startDay = start
            draft?.rules[i].endDay = end
        case .task(let i):
            if !title.isEmpty { draft?.tasks[i].title = title }
            draft?.tasks[i].dueDay = start
        case .appointment(let i):
            if !title.isEmpty { draft?.appointments[i].title = title }
        }
        looksRight()
    }

    // "3 days before surgery" under the day steppers
    func dayWords(_ day: Int) -> String {
        PlainText.upperFirst(DayMath.surgeryWords(forDay: day))
    }

    // the paper's hospital time left out AM or PM and the page could not tell
    struct AmPmQuestion {
        let title = "Was that AM or PM?"
        let detail: String
        let am: Date
        let pm: Date
        let picked: Date?
    }

    // where the shown card's medicine sits in the draft, nil on any other card
    var currentMedicineIndex: Int? {
        guard case .medicine(let i)? = currentCard?.item, draft?.medicines.indices.contains(i) == true else { return nil }
        return i
    }

    // what the paper's last given words give for one medicine
    func lastGivenReading(for m: DraftMedicine) -> LastGivenReading {
        guard let draft else { return .none }
        return LastGivenParser.reading(from: m.lastGivenText, pageText: draft.pageText, printedDate: draft.printedDate,
                                       medicineNames: [m.name] + m.alsoKnownAs)
    }

    // asked on the shown medicine's card, nil when nothing to ask
    var amPmQuestion: AmPmQuestion? {
        guard let draft, let i = currentMedicineIndex else { return nil }
        let m = draft.medicines[i]
        guard case .needsAmPm(let am, let pm) = lastGivenReading(for: m) else { return nil }
        return AmPmQuestion(detail: "Your paper says \u{201C}\(m.lastGivenText)\u{201D} without AM or PM. This sets when your next dose is.",
                            am: am, pm: pm, picked: m.lastGivenPick)
    }

    // the patient's answer, saved as the hospital time
    func pickLastGiven(_ time: Date) {
        guard let question = amPmQuestion, time == question.am || time == question.pm,
              let i = currentMedicineIndex else { return }
        draft?.medicines[i].lastGivenPick = time
    }

    // the patient says if the hospital gave a dose: the paper's time can't be read,
    // or it came a little before the first paper time
    struct HospitalDoseQuestion {
        let title: String
        let detail: String
        let doseTime: Date
        let answer: Bool?
        let yesButton = "Yes"
        let noButton = "No"
    }

    // asked on the shown medicine's card of a twice a day medicine
    func hospitalDoseQuestion(now: Date = AppClock.now()) -> HospitalDoseQuestion? {
        guard let draft, let printed = draft.printedDate, let i = currentMedicineIndex else { return nil }
        let m = draft.medicines[i]
        guard m.action == .take, m.timesOfDay.count == 2, m.minHoursBetween == nil,
              !m.lastGivenText.trimmed.isEmpty else { return nil }
        let answer = { (dose: Date) in m.hospitalDoseAnswer.flatMap { m.hospitalDoseAt == dose ? $0 : nil } }

        // a readable time a little before the first paper time, never guessed either way
        var given: Date?
        switch lastGivenReading(for: m) {
        case .time(let date): given = date
        case .needsAmPm(let am, let pm): given = m.lastGivenPick.flatMap { $0 == am || $0 == pm ? $0 : nil }
        case .none: given = nil
        }
        if let given {
            guard let dose = DoseSchedule.earlyDoseSlot(given: given, minutes: m.timesOfDay) else { return nil }
            return HospitalDoseQuestion(
                title: "Does the dose you got at \(DayMath.timeText(of: given)) count as your \(DayMath.timeText(of: dose)) dose?",
                detail: "Your paper says \u{201C}\(m.lastGivenText)\u{201D}. Your papers say to take it at \(DayMath.timeText(of: dose)).",
                doseTime: dose, answer: answer(dose))
        }
        // nothing readable and a line that says one was given, about the dose due by now on the discharge day
        guard lastGivenReading(for: m) == LastGivenReading.none, DayMath.calendar.isDate(printed, inSameDayAs: now) else { return nil }
        let day = DayMath.calendar.startOfDay(for: printed)
        let times = m.timesOfDay.sorted().map { day.addingTimeInterval(TimeInterval($0 * 60)) }
        guard let dose = times.last(where: { $0 <= now }) else { return nil }
        return HospitalDoseQuestion(
            title: "Did you already get this dose in the hospital?",
            detail: "Your paper says \u{201C}\(m.lastGivenText)\u{201D}. This is about your \(DayMath.timeText(of: dose)) dose today.",
            doseTime: dose, answer: answer(dose))
    }

    // the patient's yes or no, saved with the dose time it was about
    func answerHospitalDose(_ gotIt: Bool, now: Date = AppClock.now()) {
        guard let question = hospitalDoseQuestion(now: now), let i = currentMedicineIndex else { return }
        draft?.medicines[i].hospitalDoseAnswer = gotIt
        draft?.medicines[i].hospitalDoseAt = question.doseTime
    }
}
