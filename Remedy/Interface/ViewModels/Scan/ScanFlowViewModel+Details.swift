//
//  ScanFlowViewModel+Details.swift
//  Remedy
//
//  about this paper, before or after surgery decided by the rules
//

import Foundation

extension ScanFlowViewModel {

    var whoTitle: String { "Who gave you this paper?" }
    var detailsTitle: String { "About This Paper" }
    var foundText: String { "Found on the paper" }
    var blankText: String { "Not found, left blank" }
    var doctorFoundTitle: String { "Doctor on the paper" }
    var hospitalFoundTitle: String { "From" }
    var printedDateTitle: String { "Date printed on the paper" }
    var noDateButton: String { "No date on it" }
    var nextButton: String { "Next" }

    // MARK: - Before or after, decided by the rules

    // true when the rules sorted the papers, or the page clearly says the other kind than the patient picked
    // never asked when the rules sort it, each saved line then takes before or after from its own day
    var asksKind: Bool {
        guard let paperChoice, let guess = kindGuess else { return false }
        switch paperChoice {
        case .notSure: return false
        case .before: return guess.isSure && guess.kind != .beforeSurgery
        case .after: return guess.isSure && guess.kind != .afterSurgery
        }
    }

    // what the rules decided, said with the words they found, so the patient can correct it
    var kindNote: String {
        guard let guess = kindGuess else { return "" }
        if paperChoice != .notSure {
            return "You said \(Self.beforeOrAfter(paper)) surgery, but the page looks like \(Self.beforeOrAfter(guess.kind)) surgery papers (it says \u{201C}\(guess.clue)\u{201D}). Pick the right one."
        }
        guard guess.isSure else { return "The page doesn\u{2019}t say, so pick the right one." }
        return "Remedy decided \(Self.beforeOrAfter(guess.kind)) surgery because the page says \u{201C}\(guess.clue)\u{201D}. Change it if that\u{2019}s wrong."
    }

    private static func beforeOrAfter(_ kind: PaperKind) -> String { kind == .afterSurgery ? "after" : "before" }

    // the questions that come up for this paper
    var detailsSteps: [PaperDetailsStep] { (asksKind ? [PaperDetailsStep.kind] : []) + [.who, .date] }

    // the question on screen, as its title
    var detailsQuestion: String {
        switch detailsStep {
        case .kind: return kindQuestionTitle
        case .who: return whoTitle
        case .date: return printedDateTitle
        }
    }

    var detailsProgress: String {
        "Question \((detailsSteps.firstIndex(of: detailsStep) ?? 0) + 1) of \(detailsSteps.count)"
    }

    // the next question or after the last one the reading
    func nextDetail() async {
        if let at = detailsSteps.firstIndex(of: detailsStep), at + 1 < detailsSteps.count {
            Motion.run { detailsStep = detailsSteps[at + 1] }
        } else {
            await confirmPaperDetails()
        }
    }

    // the confirmed answers then the personal info is hidden
    func confirmPaperDetails() async {
        // a model that is not ready is never swapped for another, the patient picks
        if aiProblem != nil {
            showsAIChoice = true
            return
        }
        Motion.run { step = .reading }
        await process(scanned: lastScanned)
    }

    // puts the answers on a draft read from a scan
    func stampPaper(on draft: inout DraftPlan) {
        draft.paperSource = chosenSource ?? .other
        draft.paperField = draft.paperSource == .specialist ? chosenField : nil
        draft.otherKindText = doctorKind == .other ? otherKindText.trimmed : ""
        draft.doctorName = doctorName.trimmed
        draft.hospitalName = hospitalText.trimmed
        draft.printedDate = hasPrintedDate ? DayMath.calendar.startOfDay(for: printedDate) : nil
    }

    // the hospital named in the letterhead or logo, nil when none
    var foundHospital: String? { hospitalText.isEmpty ? nil : hospitalText }

    // the doctor the paper names, nil when it did not say
    var foundDoctor: String? {
        let name = doctorName.trimmed
        return name.isEmpty ? nil : name
    }
}
