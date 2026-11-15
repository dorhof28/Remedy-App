//
//  ClaudeAdapter.swift
//  Remedy
//
//  claude as a LanguageModel when the ClaudeForFoundationModels package is linked
//

import Foundation
import FoundationModels
#if canImport(ClaudeForFoundationModels)
import ClaudeForFoundationModels
#endif

// claude as a LanguageModel, key from the keychain
enum ClaudeAdapter {

    // where the key is saved in the Keychain
    static let keyName = "claudeAPIKey"

    #if canImport(ClaudeForFoundationModels)
    // the model picked on Add a Key, sonnet by default
    private static var picked: ClaudeModel {
        switch ProviderModels.picked(.claude) {
        case ClaudeModel.opus5_5.id: return .opus5_5
        case ClaudeModel.haiku5_5.id: return .haiku5_5
        default: return .sonnet5_5
        }
    }
    #endif

    static func model() throws -> any LanguageModel {
        #if canImport(ClaudeForFoundationModels)
        guard let key = KeychainStore.read(keyName), !key.isEmpty else { throw PlanReaderError.notReady("Claude") }
        return ClaudeLanguageModel(name: picked, auth: .apiKey(key))
        #else
        throw PlanReaderError.notReady("Claude")
        #endif
    }
}
