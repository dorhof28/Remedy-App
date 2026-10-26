//
//  ApplePlanReader.swift
//  Remedy
//
//  apples ai reads the papers
//

import Foundation
import os
import FoundationModels

struct ApplePlanReader: PlanReader {

    // cloud or phone
    enum Model { case cloud, phone }
    let model: Model

    var name: String { model == .cloud ? "Apple\u{2019}s cloud AI" : "Apple AI on this phone" }

    var isAvailable: Bool { model == .cloud ? AppleAI.isCloudAvailable : AppleAI.isPhoneAvailable }

    func readPlan(from pages: [String], paper: PaperKind) async throws -> DraftPlan {
        switch model {
        case .cloud:
            let plan = try await askCloud(pages, paper: paper)
            return AIPlanConverter.draft(from: [plan], pages: pages, paper: paper)
        case .phone:
            let (plans, warnings) = try await askPhone(pages, paper: paper)
            var draft = AIPlanConverter.draft(from: plans, pages: pages, paper: paper)
            draft.warnings.insert(contentsOf: warnings, at: 0)
            return draft
        }
    }

    // MARK: - Cloud

    // same answer every time for the same page
    private static let options = GenerationOptions(sampling: .greedy)

    private func askCloud(_ pages: [String], paper: PaperKind) async throws -> AIPlan {
        let cloud = PrivateCloudComputeLanguageModel()
        if cloud.quotaUsage.isLimitReached { throw PlanReaderError.dailyLimitReached }
        let session = LanguageModelSession(model: cloud, instructions: AIPrompt.instructions(for: paper))
        let prompt = AIPrompt.prompt(paper: paper, pages: Array(pages.enumerated()))
        return try await session.respond(to: prompt, generating: AIPlan.self, options: Self.options).content
    }

    // MARK: - Phone

    // one piece at a time
    private func askPhone(_ pages: [String], paper: PaperKind) async throws -> ([AIPlan], [String]) {
        var plans: [AIPlan] = []
        var warnings: [String] = []
        var pieceCount = 0

        for (index, page) in pages.enumerated() {
            for piece in AIPrompt.pieces(of: page) {
                pieceCount += 1
                do {
                    plans += try await askPhone(piece: piece, page: index, paper: paper, splits: 0)
                } catch let error as LanguageModelSession.GenerationError where Self.canSkip(error) {
                    PlanReaders.log.error("Skipped part of page \(index + 1): \(error.localizedDescription)")
                    let warning = "Part of page \(index + 1) couldn\u{2019}t be read. Check it on the paper yourself."
                    if !warnings.contains(warning) { warnings.append(warning) }
                }
            }
        }
        if plans.isEmpty && pieceCount > 0 { throw PlanReaderError.couldNotRead }
        return (plans, warnings)
    }

    // one piece
    private func askPhone(piece: String, page: Int, paper: PaperKind, splits: Int) async throws -> [AIPlan] {
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: AIPrompt.instructions(for: paper, examples: 1))
        let prompt = AIPrompt.prompt(paper: paper, pages: [(offset: page, element: piece)])
        do {
            return [try await session.respond(to: prompt, generating: AIPlan.self, options: Self.options).content]
        } catch let error as LanguageModelSession.GenerationError {
            guard case .exceededContextWindowSize = error, splits < 3, piece.count > 400 else { throw error }
            var plans: [AIPlan] = []
            for half in AIPrompt.pieces(of: piece, size: piece.count / 2 + 1) {
                plans += try await askPhone(piece: half, page: page, paper: paper, splits: splits + 1)
            }
            return plans
        }
    }

    // errors about one piece's words
    private static func canSkip(_ error: LanguageModelSession.GenerationError) -> Bool {
        switch error {
        case .exceededContextWindowSize, .guardrailViolation, .refusal, .decodingFailure, .unsupportedLanguageOrLocale:
            return true
        default:
            return false
        }
    }
}
