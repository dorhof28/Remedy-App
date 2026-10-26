//
//  GeminiPlanReader.swift
//  Remedy
//
//  gemini reads the papers as the backup
//

import Foundation
import os

struct GeminiPlanReader: PlanReader {

    // where the key is saved in the Keychain
    static let keyName = "geminiAPIKey"

    let name = "Google Gemini"

    // saves GEMINI_API_KEY from a private xcode scheme into the keychain
    // only exists when run from xcode so the key never goes in the code
    static func saveKeyFromXcode() {
        let key = (ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.hasPrefix("PASTE"), KeychainStore.read(keyName) != key else { return }
        _ = KeychainStore.save(key, for: keyName)
        PlanReaders.log.info("Saved the Gemini key from the Xcode scheme")
    }

    // ready when a key has been saved in Settings
    var isAvailable: Bool { !(KeychainStore.read(Self.keyName) ?? "").isEmpty }

    func readPlan(from pages: [String], paper: PaperKind) async throws -> DraftPlan {
        guard let key = KeychainStore.read(Self.keyName), !key.isEmpty else { throw PlanReaderError.aiUnavailable }

        // safety net the fixed rules once more
        let clean = pages.map { Redactor.redact($0).text }

        let json = try await GeminiClient.generateJSON(
            instructions: AIPrompt.instructions(for: paper),
            prompt: AIPrompt.prompt(paper: paper, pages: Array(clean.enumerated())),
            schema: GeminiSchema.plan,
            apiKey: key)

        guard let plan = try? JSONDecoder().decode(AIPlan.self, from: json) else {
            throw PlanReaderError.couldNotRead
        }
        return AIPlanConverter.draft(from: [plan], pages: clean, paper: paper)
    }
}
