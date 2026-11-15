//
//  OpenAICompatibleAdapter.swift
//  Remedy
//
//  any openai compatible server as a LanguageModel when FoundationModelsUtilities is linked
//

import Foundation
import FoundationModels
#if canImport(FoundationModelsUtilities)
import FoundationModelsUtilities
#endif

// any openai compatible server as a LanguageModel
enum OpenAICompatibleAdapter {

    // each preset keeps its own key (Keychain) model name and address (UserDefaults)
    // Custom keeps the names used before the presets so saved settings still work
    static func keyName(for choice: ModelChoice) -> String {
        choice.id == .openAICompatible ? "openAICompatibleAPIKey" : "\(choice.id.rawValue)APIKey"
    }
    static func modelKey(for choice: ModelChoice) -> String {
        choice.id == .openAICompatible ? "openAICompatibleModel" : "\(choice.id.rawValue)Model"
    }
    static func addressKey(for choice: ModelChoice) -> String {
        choice.id == .openAICompatible ? "openAICompatibleURL" : "\(choice.id.rawValue)Address"
    }

    // the base url, a full address is used as typed and a Mac name becomes name.local
    static func baseURL(for choice: ModelChoice, address: String?) -> URL? {
        guard let preset = choice.baseURL else { return nil }
        guard choice.asksAddress else { return URL(string: preset) }
        let typed = (address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if typed.isEmpty { return nil }
        if typed.lowercased().hasPrefix("http") { return URL(string: typed) }
        return URL(string: preset.replacingOccurrences(of: "<name>", with: typed))
    }

    // sessionConfiguration is only for tests
    static func model(for choice: ModelChoice, defaults: UserDefaults = .standard,
                      sessionConfiguration: URLSessionConfiguration? = nil) throws -> any LanguageModel {
        #if canImport(FoundationModelsUtilities)
        let key = KeychainStore.read(keyName(for: choice)) ?? ""
        let typedName = defaults.string(forKey: modelKey(for: choice)) ?? ""
        let name = typedName.isEmpty ? choice.defaultModel : typedName
        guard let url = baseURL(for: choice, address: defaults.string(forKey: addressKey(for: choice))),
              !name.isEmpty, !choice.needsKey || !key.isEmpty else {
            throw PlanReaderError.notReady(choice.displayName)
        }
        let headers = key.isEmpty ? [:] : ["Authorization": "Bearer \(key)"]
        // a model on the patient's Mac gets minutes to answer instead of the usual one
        let config = sessionConfiguration ?? (choice.group == .yourMac ? MacConnector.planningConfiguration : nil)
        return ChatCompletionsLanguageModel(name: name, url: url, additionalHeaders: headers,
                                            urlSessionConfiguration: config)
        #else
        throw PlanReaderError.notReady(choice.displayName)
        #endif
    }
}
