//
//  MacConnectionViewModel.swift
//  Remedy
//
//  connecting to an ai on the patient's own Mac, shared by both looks
//

import Foundation
import Observation

// connecting to a model on the patient's own mac
@Observable
final class MacConnectionViewModel {

    enum State: Equatable {
        case idle, checking
        case connected(MacConnection)
        case failed(String)
    }

    private let choice = ModelChoice.choice(.yourMac)
    private let defaults: UserDefaults
    private let connect: (String, String) async -> Result<MacConnection, MacConnectError>
    private let saveKey: (String) -> Void

    var name: String
    // only oMLX asks for one, kept in the keychain
    var key: String
    var state: State = .idle
    var model: String

    init(defaults: UserDefaults = .standard,
         readKey: () -> String = { KeychainStore.read(OpenAICompatibleAdapter.keyName(for: .choice(.yourMac))) ?? "" },
         saveKey: @escaping (String) -> Void = { MacConnectionViewModel.storeKey($0) },
         connect: @escaping (String, String) async -> Result<MacConnection, MacConnectError> = { await MacConnector.connect($0, key: $1) }) {
        self.defaults = defaults
        self.connect = connect
        self.saveKey = saveKey
        key = readKey()
        name = defaults.string(forKey: OpenAICompatibleAdapter.addressKey(for: .choice(.yourMac))) ?? ""
        model = defaults.string(forKey: OpenAICompatibleAdapter.modelKey(for: .choice(.yourMac))) ?? ""
    }

    // MARK: - Words

    let title = "Your Mac"
    let subtitle = "Run a big model on your Mac and use it from this iPhone. Your papers stay on your home Wi\u{2011}Fi."
    let namePrompt = "Mac name or address"
    let keyPrompt = "API key (oMLX only)"
    let nameHint = "Find it on your Mac in System Settings, General, Sharing, Local hostname."
    let checkButton = "Connect"
    let checkingText = "Looking for your Mac\u{2026}"
    let modelTitle = "Model"
    let recommendedTag = "Best for your Mac"
    let setupTitle = "Set up your Mac"
    let setupSteps = [
        "LM Studio: open the Developer tab, start the server and turn on Serve on Local Network.",
        "Or oMLX: in its settings set the server host to 0.0.0.0, restart it, and copy its API key here.",
        "Or Ollama: in Terminal run  launchctl setenv OLLAMA_HOST 0.0.0.0  then quit and reopen Ollama.",
        "Keep the Mac awake and on the same Wi\u{2011}Fi as this iPhone.",
    ]

    var connectedText: String? {
        guard case .connected(let found) = state else { return nil }
        return "Connected to \(found.server.name) \u{00B7} \(PlainText.count(found.models.count, "model"))"
    }

    var models: [String] {
        guard case .connected(let found) = state else { return [] }
        return found.models.filter(MacModelPick.isChatModel)
    }

    var recommended: String? { MacModelPick.best(of: models) }

    var errorText: String? {
        guard case .failed(let text) = state else { return nil }
        return text
    }

    var isChecking: Bool { state == .checking }
    var canCheck: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !isChecking }

    // MARK: - Actions

    // asks the Mac for its models and saves the address that answered
    func check() async {
        state = .checking
        switch await connect(name, key.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case .success(let found):
            state = .connected(found)
            saveKey(key.trimmingCharacters(in: .whitespacesAndNewlines))
            defaults.set(found.baseURL.absoluteString, forKey: OpenAICompatibleAdapter.addressKey(for: choice))
            let usable = found.models.filter(MacModelPick.isChatModel)
            if !usable.contains(model), let best = MacModelPick.best(of: usable) { pick(best) }
        case .failure(let error):
            state = .failed(Self.message(for: error))
        }
    }

    // saves the picked model for this reader
    func pick(_ name: String) {
        model = name
        defaults.set(name, forKey: OpenAICompatibleAdapter.modelKey(for: choice))
    }

    static func message(for error: MacConnectError) -> String {
        switch error {
        case .noName: return "Type your Mac\u{2019}s name first."
        case .notFound: return "Couldn\u{2019}t reach your Mac. Check it\u{2019}s awake, on the same Wi\u{2011}Fi, and the server allows the local network."
        case .noModels(let server): return "\(server.name) answered but has no models loaded. Download one on your Mac first."
        case .needsKey(let server): return "\(server.name) needs its API key. Copy it from \(server.name)\u{2019}s settings on your Mac."
        }
    }

    // an empty key clears the old one
    static func storeKey(_ key: String) {
        let account = OpenAICompatibleAdapter.keyName(for: .choice(.yourMac))
        if key.isEmpty { KeychainStore.delete(account) } else { _ = KeychainStore.save(key, for: account) }
    }

    // the short name of a model without its maker like qwen3.6-35b-a3b
    func shortName(_ model: String) -> String {
        model.split(separator: "/").last.map(String.init) ?? model
    }
}
