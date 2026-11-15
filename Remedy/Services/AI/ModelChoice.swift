//
//  ModelChoice.swift
//  Remedy
//
//  which ai reads the papers and the two choices the patient makes
//

import Foundation

// one ai the patient can pick
struct ModelChoice: Identifiable, Equatable {

    // every reader the patient can pick
    enum ID: String {
        case onPhone, applePrivateCloud, claude, gemini, openAI, yourMac, openRouter, groq, mistral
        case openAICompatible   // Custom, the raw value is kept so saved settings still open
    }

    // where the ai runs
    enum Group {
        case onPhone, offlineDownload, applePrivateCloud, yourMac, cloud
    }

    let id: ID
    let displayName: String
    let group: Group
    let canReadPhoto: Bool
    let needsKey: Bool
    // for the openai compatible presets only
    var baseURL: String? = nil
    var defaultModel = ""
    // one plain line under the name
    var hint: String? = nil

    // these use the one openai compatible adapter
    var usesCompatibleAdapter: Bool { baseURL != nil }
    // the patient types the address, Your own Mac only its name
    var asksAddress: Bool { id == .yourMac || id == .openAICompatible }

    // only the phone and downloaded models keep the papers here
    var sendsDataOffPhone: Bool { group != .onPhone && group != .offlineDownload }

    static let onPhone = ModelChoice(id: .onPhone, displayName: "On this iPhone", group: .onPhone, canReadPhoto: true, needsKey: false)

    static let all = [
        onPhone,
        ModelChoice(id: .applePrivateCloud, displayName: "Apple Private Cloud", group: .applePrivateCloud, canReadPhoto: true, needsKey: false),
        ModelChoice(id: .yourMac, displayName: "Your Mac", group: .yourMac, canReadPhoto: true, needsKey: false,
                    baseURL: "http://<name>.local:11434/v1", defaultModel: "llama3.2-vision", hint: "Free, runs on your Mac"),
        ModelChoice(id: .claude, displayName: "Claude", group: .cloud, canReadPhoto: true, needsKey: true, hint: "Paid"),
        // free tiers may train on what they get, so only use them with sample papers
        ModelChoice(id: .gemini, displayName: "Google Gemini", group: .cloud, canReadPhoto: true, needsKey: true, hint: "Free tier available, check limits"),
        ModelChoice(id: .openAI, displayName: "OpenAI", group: .cloud, canReadPhoto: true, needsKey: true,
                    baseURL: "https://api.openai.com/v1", defaultModel: "gpt-5-mini", hint: "Paid"),
        ModelChoice(id: .openRouter, displayName: "OpenRouter", group: .cloud, canReadPhoto: true, needsKey: true,
                    baseURL: "https://openrouter.ai/api/v1", defaultModel: "openrouter/free", hint: "Free tier available, check limits (:free models)"),
        ModelChoice(id: .groq, displayName: "Groq", group: .cloud, canReadPhoto: true, needsKey: true,
                    baseURL: "https://api.groq.com/openai/v1", defaultModel: "meta-llama/llama-4-scout-17b-16e-instruct", hint: "Free tier available, check limits"),
        ModelChoice(id: .mistral, displayName: "Mistral", group: .cloud, canReadPhoto: true, needsKey: true,
                    baseURL: "https://api.mistral.ai/v1", defaultModel: "mistral-small-latest", hint: "Free tier available, check limits"),
        ModelChoice(id: .openAICompatible, displayName: "Custom address", group: .cloud, canReadPhoto: true, needsKey: true,
                    baseURL: "", defaultModel: ""),
    ]

    static func choice(_ id: ID) -> ModelChoice {
        all.first { $0.id == id } ?? onPhone
    }
}

extension ModelChoice {
    // what leaves the phone, in one plain line
    func leavesPhoneLine(sendsPhoto: Bool) -> String {
        if !sendsDataOffPhone { return "Nothing leaves this iPhone" }
        return sendsPhoto ? "Checked text and a blacked-out photo are sent" : "Only the checked text is sent"
    }

    // the short name in the one line summary
    var summaryName: String { sendsDataOffPhone ? displayName : "on this iPhone" }
}

// part 1, how the words come off the page, always on this iphone or apple private cloud
// the camera reading always runs too since its word boxes black out the photo
enum ReadingChoice: String, CaseIterable, Identifiable {
    case camera         // apple vision plus remedy's own layout rules
    case glmOCR         // a downloaded model made for reading papers
    case gemma          // gemma 4 downloaded
    case gemmaLarge     // gemma 4 large downloaded
    case privateCloud   // apple private cloud compute

    var id: String { rawValue }

    var localModel: LocalModel? {
        switch self {
        case .glmOCR: return .glmOCR
        case .gemma: return .gemmaSmall
        case .gemmaLarge: return .gemmaLarge
        case .camera, .privateCloud: return nil
        }
    }

    var title: String {
        switch self {
        case .camera: return "iPhone camera reading"
        case .privateCloud: return "Apple Private Cloud"
        default: return localModel?.displayName ?? ""
        }
    }

    var detail: String {
        switch self {
        case .camera: return "Fast. Rebuilds lists and columns. Nothing leaves this iPhone."
        case .privateCloud: return "Apple\u{2019}s private servers read the page. Apple can\u{2019}t see or keep it."
        default: return (localModel?.purpose ?? "") + " Runs on this iPhone."
        }
    }

    var symbol: String {
        switch self {
        case .camera: return "text.viewfinder"
        case .privateCloud: return "lock.icloud"
        default: return "cpu"
        }
    }

    var summaryName: String {
        switch self {
        case .camera: return "iPhone camera"
        case .privateCloud: return "Apple Private Cloud"
        default: return (localModel?.displayName ?? "") + " on this iPhone"
        }
    }
}

// which step hides names and details before anything is read, never a cloud ai
enum RedactionChoice: String, CaseIterable, Identifiable {
    case phoneAI        // the Apple model on this iPhone plus the fixed rules
    case gemma          // gemma 4 downloaded, plus the fixed rules
    case gemmaLarge     // gemma 4 large downloaded, plus the fixed rules
    case privateCloud   // apple private cloud compute plus the fixed rules
    case rulesOnly      // the fixed rules alone

    var id: String { rawValue }

    var localModel: LocalModel? {
        switch self {
        case .gemma: return .gemmaSmall
        case .gemmaLarge: return .gemmaLarge
        default: return nil
        }
    }

    var usesAI: Bool { self != .rulesOnly }

    var title: String {
        switch self {
        case .phoneAI: return "Apple Intelligence on this iPhone"
        case .privateCloud: return "Apple Private Cloud"
        case .rulesOnly: return "Fixed rules only"
        default: return (localModel?.displayName ?? "") + " on this iPhone"
        }
    }

    // says what leaves the phone
    var detail: String {
        switch self {
        case .phoneAI: return "Finds names and details on this iPhone. Nothing leaves it."
        case .privateCloud: return "Apple\u{2019}s private servers find names. Apple can\u{2019}t see or keep the page."
        case .rulesOnly: return "Simple rules, no AI. Can miss a name, so check the page."
        default: return "A bigger model you downloaded. Nothing leaves this iPhone."
        }
    }

    var symbol: String {
        switch self {
        case .phoneAI: return "sparkles"
        case .privateCloud: return "lock.icloud"
        case .rulesOnly: return "list.bullet.rectangle"
        default: return "cpu"
        }
    }

    var summaryName: String {
        switch self {
        case .phoneAI: return "on this iPhone"
        case .privateCloud: return "Apple Private Cloud"
        case .rulesOnly: return "fixed rules"
        default: return (localModel?.displayName ?? "") + " on this iPhone"
        }
    }
}

// what stops the picked models from being used, said to the patient and never skipped
enum AIProblem: Equatable {
    case hiding
    case pageReading(String)
    case reading(String)

    var message: String {
        switch self {
        case .hiding:
            return "The AI that hides your name isn\u{2019}t ready on this iPhone. Pick another, or fixed rules only."
        case .pageReading(let name):
            return "\(name) isn\u{2019}t ready to read the page. Download it in Settings or pick iPhone camera reading."
        case .reading(let name):
            return "\(name) isn\u{2019}t ready. Pick another way to read your papers."
        }
    }
}

// the patient's ai settings saved in UserDefaults never keys
struct ModelSettings: Equatable {
    var readingChoice = ReadingChoice.camera        // part 1 paper to text
    var plannerChoice = ModelChoice.onPhone         // part 2 build the plan
    var redactBeforePlanning = true
    var sendTextOnly = false
    var redactionChoice = RedactionChoice.phoneAI

    // the first thing that is not ready, nil when every pick can be used
    // hidingReady is about the picked hiding ai, fixed rules are always ready
    func problem(phoneAIReady hidingReady: Bool, pageReaderReady: Bool = true, readerReady: Bool) -> AIProblem? {
        if redactBeforePlanning && redactionChoice.usesAI && !hidingReady { return .hiding }
        if !pageReaderReady { return .pageReading(readingChoice.title) }
        if !readerReady { return .reading(plannerChoice.displayName) }
        return nil
    }

    // the ai the patient can pick to read, the phone always and others only once set up
    // the one picked now stays in the list so it never vanishes
    func readerChoices(isReady: (ModelChoice) -> Bool) -> [ModelChoice] {
        ModelChoice.all.filter { $0.id == .onPhone || $0.id == plannerChoice.id || isReady($0) }
    }

    // off is allowed but the patient has to confirm before anything leaves the phone
    var needsRedactionWarning: Bool { !redactBeforePlanning && plannerChoice.sendsDataOffPhone }

    // the photo goes along unless the model cant read it or the patient said text only
    func attachesPhoto(for choice: ModelChoice) -> Bool {
        choice.canReadPhoto && !(sendTextOnly && choice.sendsDataOffPhone)
    }

    static let textReaderKey = "textReaderChoice"
    static let plannerKey = "plannerChoice"
    static let redactKey = "redactBeforePlanning"
    static let redactionChoiceKey = "redactionChoice"
    // the settings switch "send blacked out photos" so on means photos go
    static let sendsPhotosKey = "sendsPagePictures"

    // reads the saved choices, unknown values fall back to the defaults
    static func load(from defaults: UserDefaults = .standard) -> ModelSettings {
        var settings = ModelSettings()
        if let raw = defaults.string(forKey: textReaderKey), let saved = ReadingChoice(rawValue: raw) {
            settings.readingChoice = saved
        }
        if let raw = defaults.string(forKey: plannerKey), let id = ModelChoice.ID(rawValue: raw) {
            settings.plannerChoice = ModelChoice.choice(id)
        }
        settings.redactBeforePlanning = defaults.object(forKey: redactKey) as? Bool ?? true
        if let raw = defaults.string(forKey: redactionChoiceKey), let saved = RedactionChoice(rawValue: raw) {
            settings.redactionChoice = saved
        }
        settings.sendTextOnly = !(defaults.object(forKey: sendsPhotosKey) as? Bool ?? true)
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(readingChoice.rawValue, forKey: Self.textReaderKey)
        defaults.set(plannerChoice.id.rawValue, forKey: Self.plannerKey)
        defaults.set(redactBeforePlanning, forKey: Self.redactKey)
        defaults.set(redactionChoice.rawValue, forKey: Self.redactionChoiceKey)
        defaults.set(!sendTextOnly, forKey: Self.sendsPhotosKey)
    }
}

// the models offered for a provider with a fixed list, the first is the default
enum ProviderModels {
    // one model a provider offers
    struct Option: Hashable { let id: String; let title: String }

    // the models offered for each provider, first is the default
    static func options(_ id: ModelChoice.ID) -> [Option] {
        switch id {
        case .claude:
            return [Option(id: "claude-sonnet-5-5", title: "Claude Sonnet 5.5"),
                    Option(id: "claude-opus-5-5", title: "Claude Opus 5.5"),
                    Option(id: "claude-haiku-5-5", title: "Claude Haiku 5.5")]
        case .gemini:
            // the latest aliases keep working when google retires a model
            return [Option(id: "gemini-flash-latest", title: "Gemini Flash"),
                    Option(id: "gemini-pro-latest", title: "Gemini Pro")]
        default: return []
        }
    }

    static func key(_ id: ModelChoice.ID) -> String { "\(id.rawValue)Model" }

    // the saved pick, or the default when nothing valid is saved
    static func picked(_ id: ModelChoice.ID, defaults: UserDefaults = .standard) -> String {
        let all = options(id)
        let saved = defaults.string(forKey: key(id)) ?? ""
        return all.contains { $0.id == saved } ? saved : (all.first?.id ?? "")
    }
}
