//
//  GeminiPlanReader.swift
//  Remedy
//
//  gemini reads the papers when the patient picks it
//

import Foundation
import os

// reads papers with gemini, only when the patient picked it and added a key
struct GeminiPlanReader: PlanReader {

    // where the key is saved in the Keychain
    static let keyName = "geminiAPIKey"

    let name = "Google Gemini"

    // ready when a key has been saved in Settings
    var isAvailable: Bool { !(KeychainStore.read(Self.keyName) ?? "").isEmpty }

    func readPlan(from pages: [String], pictures: [Data?], paper: PaperKind) async throws -> DraftPlan {
        guard let key = KeychainStore.read(Self.keyName), !key.isEmpty else { throw PlanReaderError.notReady(name) }
        let jpegs = pictures.compactMap { $0 }

        // safety net the fixed rules once more
        let clean = pages.map { Redactor.redact($0).text }

        let json = try await GeminiClient.generateJSON(
            instructions: AIPrompt.instructions(for: paper),
            prompt: AIPrompt.prompt(paper: paper, pages: Array(clean.enumerated()), hasPhotos: !jpegs.isEmpty),
            jpegs: jpegs,
            schema: GeminiSchema.plan,
            apiKey: key)

        guard let plan = try? JSONDecoder().decode(AIPlan.self, from: json) else {
            throw PlanReaderError.couldNotRead
        }
        return AIPlanConverter.draft(from: [plan], pages: clean, paper: paper)
    }
}
