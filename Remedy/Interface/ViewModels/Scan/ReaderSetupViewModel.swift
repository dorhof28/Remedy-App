//
//  ReaderSetupViewModel.swift
//  Remedy
//
//  the "how your papers are read" sheet for both looks
//  three steps, a card for each choice with where the page goes, and the download words
//

import Foundation

// where the page goes for one choice, in words anyone understands
enum PrivacyPlace: Equatable {
    case thisPhone, appleCloud, homeNetwork, online

    var label: String {
        switch self {
        case .thisPhone: return "Stays on this iPhone"
        case .appleCloud: return "Apple Private Cloud"
        case .homeNetwork: return "Stays on your home network"
        case .online: return "Online"
        }
    }

    // two words for the badge on a row
    var shortLabel: String {
        switch self {
        case .thisPhone: return "On iPhone"
        case .appleCloud: return "Private Cloud"
        case .homeNetwork: return "At home"
        case .online: return "Leaves phone"
        }
    }

    var symbol: String {
        switch self {
        case .thisPhone: return "iphone"
        case .appleCloud: return "lock.icloud.fill"
        case .homeNetwork: return "house.fill"
        case .online: return "globe"
        }
    }

    // green when nothing leaves, orange when a company gets the hidden page
    var tone: Tone {
        switch self {
        case .thisPhone, .homeNetwork: return .good
        case .appleCloud: return .info
        case .online: return .caution
        }
    }

    static func of(_ choice: ReadingChoice) -> PrivacyPlace { choice == .privateCloud ? .appleCloud : .thisPhone }
    static func of(_ choice: RedactionChoice) -> PrivacyPlace { choice == .privateCloud ? .appleCloud : .thisPhone }
    // where a reader sends the page
    static func of(_ choice: ModelChoice) -> PrivacyPlace {
        switch choice.group {
        case .onPhone, .offlineDownload: return .thisPhone
        case .applePrivateCloud: return .appleCloud
        case .yourMac: return .homeNetwork
        case .cloud: return .online
        }
    }
}

// the three steps a page goes through
enum ReaderStep: Int, CaseIterable, Identifiable {
    case page, hiding, plan
    var id: Int { rawValue }

    var number: Int { rawValue + 1 }

    var title: String {
        switch self {
        case .page: return "Reading the page"
        case .hiding: return "Hiding your name"
        case .plan: return "Making your plan"
        }
    }

    // one plain sentence under the title
    var note: String {
        switch self {
        case .page: return "Turns the photo of your paper into words."
        case .hiding: return "Your name and record numbers are blacked out before anything else sees the page. You check it after."
        case .plan: return "Finds your medicines, instructions and visits on the checked page."
        }
    }

    var symbol: String {
        switch self {
        case .page: return "text.viewfinder"
        case .hiding: return "eye.slash.fill"
        case .plan: return "list.bullet.clipboard.fill"
        }
    }

    // the simple look asks one at a time
    var question: String {
        switch self {
        case .page: return "What reads the page?"
        case .hiding: return "What hides your name?"
        case .plan: return "What makes your plan?"
        }
    }
}

// one choice as a card
struct ReaderCard: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
    let privacy: PrivacyPlace
    var isRecommended = false
    var isSelected = false
    var isReady = true
    var model: LocalModel? = nil   // a model that has to be downloaded first
}

// the reader setup steps: reading the page, hiding names, making the plan
struct ReaderSetupViewModel {

    var settings: ModelSettings
    // what can be used right now, swapped in tests
    var pageReady: (ReadingChoice) -> Bool
    var hidingReady: (RedactionChoice) -> Bool
    var planReady: (ModelChoice) -> Bool
    var showsCloud = AppleAI.usesCloud
    var fits: (LocalModel) -> Bool = { $0.fitsThisPhone }

    // the running app
    static func live(_ settings: ModelSettings) -> ReaderSetupViewModel {
        ReaderSetupViewModel(
            settings: settings,
            pageReady: { PageModelReader.isReady($0) || LaunchOptions.usesFakeAI },
            hidingReady: { AIChoiceView.isReady($0) },
            planReady: { choice in
                choice.id == .onPhone ? AppleAI.isPhoneAvailable || LaunchOptions.usesFakeAI : AIChoiceView.isReady(choice)
            })
    }

    static let title = "How your papers are read"
    static let intro = "Three steps turn your papers into a plan. Your name is hidden before anything leaves this iPhone."
    static let recommendedText = "Recommended"
    static let modelsTitle = "Downloads"
    static let modelsNote = "Downloaded once over Wi\u{2011}Fi. With these, your papers never leave this iPhone."
    static let noModelsText = "This iPhone can\u{2019}t run downloaded models. The iPhone camera and Apple Intelligence still work."
    let doneButton = "Done"
    let nextButton = "Next"

    // MARK: - Cards

    func cards(for step: ReaderStep) -> [ReaderCard] {
        switch step {
        case .page: return pageCards
        case .hiding: return hidingCards
        case .plan: return planCards
        }
    }

    // a model this iphone can never run is left out so nobody picks a dead end
    private func shows(_ model: LocalModel?) -> Bool { model.map(fits) ?? true }

    var pageCards: [ReaderCard] {
        ReadingChoice.allCases
            .filter { ($0 != .privateCloud || showsCloud) && shows($0.localModel) }
            .map { choice in
                let ready = pageReady(choice)
                return ReaderCard(id: choice.rawValue, symbol: choice.symbol, title: choice.title,
                                  detail: ready ? choice.detail : needsLine(choice.localModel, fallback: "Not available on this iPhone yet."),
                                  privacy: .of(choice), isRecommended: choice == .camera,
                                  isSelected: settings.readingChoice == choice, isReady: ready, model: choice.localModel)
            }
    }

    var hidingCards: [ReaderCard] {
        let recommended = RedactionChoice.allCases.first { $0 != .privateCloud && shows($0.localModel) && hidingReady($0) } ?? .rulesOnly
        return RedactionChoice.allCases
            .filter { ($0 != .privateCloud || showsCloud) && shows($0.localModel) }
            .map { choice in
                let ready = hidingReady(choice)
                let detail: String
                if ready { detail = choice.detail }
                else if choice == .phoneAI { detail = "Turn on Apple Intelligence in the Settings app to use this." }
                else { detail = needsLine(choice.localModel, fallback: "Not available on this iPhone yet.") }
                return ReaderCard(id: choice.rawValue, symbol: choice.symbol, title: choice.title, detail: detail,
                                  privacy: .of(choice), isRecommended: choice == recommended,
                                  isSelected: settings.redactionChoice == choice, isReady: ready, model: choice.localModel)
            }
    }

    var planCards: [ReaderCard] {
        settings.readerChoices(isReady: { $0.id != .applePrivateCloud && planReady($0) })
            .map { choice in
                let ready = planReady(choice)
                let detail = ready ? choice.leavesPhoneLine(sendsPhoto: settings.attachesPhoto(for: choice))
                                   : "Not ready. Turn on Apple Intelligence or set it up in Settings."
                return ReaderCard(id: choice.id.rawValue, symbol: choice.sendsDataOffPhone ? "cloud.fill" : "iphone",
                                  title: choice.displayName, detail: detail, privacy: .of(choice),
                                  isRecommended: choice.id == .onPhone, isSelected: settings.plannerChoice.id == choice.id,
                                  isReady: ready)
            }
    }

    // what a not ready model card says
    private func needsLine(_ model: LocalModel?, fallback: String) -> String {
        guard let model else { return fallback }
        return "Download it first. It takes \(model.sizeText)."
    }

    // the note under the plan step, more choices come with a key
    var planNote: String { ReaderStep.plan.note + " More choices, like Claude, are added with a key in Settings." }

    func note(for step: ReaderStep) -> String { step == .plan ? planNote : step.note }

    // MARK: - Picking

    // false when the card can not be picked yet
    @discardableResult
    mutating func pick(_ id: String, in step: ReaderStep) -> Bool {
        guard let card = cards(for: step).first(where: { $0.id == id }), card.isReady else { return false }
        switch step {
        case .page:
            guard let choice = ReadingChoice(rawValue: id) else { return false }
            settings.readingChoice = choice
        case .hiding:
            guard let choice = RedactionChoice(rawValue: id) else { return false }
            settings.redactionChoice = choice
        case .plan:
            guard let raw = ModelChoice.ID(rawValue: id) else { return false }
            settings.plannerChoice = ModelChoice.choice(raw)
        }
        return true
    }

    // the reader picked for a step, for the row on the list of steps
    func current(for step: ReaderStep) -> ReaderCard? {
        cards(for: step).first(where: \.isSelected)
    }

    // "Step 2 of 3"
    func progress(_ step: ReaderStep) -> String { "Step \(step.number) of \(ReaderStep.allCases.count)" }

    // MARK: - Downloads

    // "42%"
    static func percentText(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded(.down)))%"
    }

    // "670 MB of 1.6 GB"
    static func amountText(_ fraction: Double, of model: LocalModel) -> String {
        let done = Int64(Double(model.bytes) * min(max(fraction, 0), 1))
        return "\(ByteCountFormatter.string(fromByteCount: done, countStyle: .file)) of \(model.sizeText)"
    }

    static func downloadButton(_ model: LocalModel) -> String { "Download \(model.sizeText)" }
    static let retryButton = "Try again"
    static let cancelButton = "Cancel"
    static let readyText = "Downloaded"
    static let deleteButton = "Delete"
}
