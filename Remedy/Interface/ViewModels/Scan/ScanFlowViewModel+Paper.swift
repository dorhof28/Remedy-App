//
//  ScanFlowViewModel+Paper.swift
//  Remedy
//
//  words and picks for About This Paper (85)
//

import Foundation

extension ScanFlowViewModel {

    var fromPageTitle: String { "From the page" }
    var coversTitle: String { "Covers" }
    var doctorTitle: String { "Doctor" }
    var printedOnTitle: String { "Printed on" }
    var noDateTitle: String { "No date on the paper" }
    var notFoundText: String { "Not found" }
    var beforeSurgeryTitle: String { "Before surgery" }
    var afterSurgeryTitle: String { "After surgery" }

    // "Reading with Apple's cloud."
    var readingWithFooter: String {
        let planner = settings.plannerChoice
        if planner.id == .applePrivateCloud { return "Reading with Apple\u{2019}s cloud." }
        return planner.sendsDataOffPhone ? "Reading with \(planner.displayName)." : "Reading on this iPhone."
    }

    // the giver row that shows picked, from what the page said until the patient picks
    var shownGiver: NewerPaperRule.Giver? { giver ?? Self.giver(for: chosenSource) }

    // the rule 6 giver for a paper source
    static func giver(for source: PaperSource?) -> NewerPaperRule.Giver? {
        switch source {
        case .surgeryTeam?: return .surgeonsOffice
        case .hospitalRecord?: return .hospital
        case .specialist?, .primaryCare?: return .anotherDoctor
        case .other?, nil: return nil
        }
    }

    // picks the giver and the source the paper check knows
    func pickGiver(_ picked: NewerPaperRule.Giver) {
        giver = picked
        switch picked {
        case .surgeonsOffice, .hospital: chooseSource(.surgeryTeam)
        case .anotherDoctor:
            if chosenSource != .specialist && chosenSource != .primaryCare { chooseSource(.specialist) }
            isPickingDoctorKind = false
        case .pharmacy: chooseSource(.other)
        }
    }

    var printedDateText: String {
        printedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }
}

// MARK: - 86 consent with your own key

extension ScanFlowViewModel {

    var namesNotHiddenTitle: String { "Names are not hidden" }
    var namesNotHiddenDetail: String { "You turned off name hiding. Turn It Back On in Names to Hide." }

    // the caution row shows only while name hiding is off
    var showsNamesNotHidden: Bool { !settings.redactBeforePlanning && planner.sendsDataOffPhone }

    // "Page 1 of 3 · Names are not hidden." or the black bars line
    func consentCaption(_ index: Int) -> String {
        let page = redactedPages.count > 1 ? "Page \(index + 1) of \(redactedPages.count) \u{00B7} " : ""
        return page + (showsNamesNotHidden ? "Names are not hidden." : "Black bars are hidden parts.")
    }

    // a key for the provider the patient picked
    var usesOwnKey: Bool { planner.needsKey }

    var whereRowSymbol: String { usesOwnKey ? "key" : "lock" }

    // "Claude (Anthropic), using your own key. Anthropic's rules for your key apply."
    var whereRowText: String {
        guard usesOwnKey else { return whereRowDetail }
        return ProviderWords.whereItGoes(planner)
    }

    // only Apple's cloud says it asks again, no training claim for other providers
    var consentFootnoteText: String {
        guard usesOwnKey else { return consentFootnote }
        return AIPagesWords.isFree(planner) ? "Nothing has been sent yet. \(AIPagesWords.freeFooter)" : "Nothing has been sent yet."
    }
}

// plain names for the companies behind each key
enum ProviderWords {
    // the company behind a cloud reader, nil when it stays on the phone
    static func company(_ choice: ModelChoice) -> String? {
        switch choice.id {
        case .claude: return "Anthropic"
        case .gemini: return "Google"
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .groq: return "Groq"
        case .mistral: return "Mistral"
        default: return nil
        }
    }

    // the short name on the key list, "Gemini" not "Google Gemini"
    static func shortName(_ choice: ModelChoice) -> String {
        switch choice.id {
        case .gemini: return "Gemini"
        case .openAICompatible: return "Custom"
        default: return choice.displayName
        }
    }

    // the sentence saying where the pages go
    static func whereItGoes(_ choice: ModelChoice) -> String {
        let name = shortName(choice)
        guard let company = company(choice) else {
            return "\(name), at the address you typed, using your own key. Its rules for your key apply."
        }
        let label = company == name ? name : "\(name) (\(company))"
        return "\(label), using your own key. \(company)\u{2019}s rules for your key apply."
    }
}
