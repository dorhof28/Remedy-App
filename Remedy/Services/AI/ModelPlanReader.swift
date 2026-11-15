//
//  ModelPlanReader.swift
//  Remedy
//
//  one reader for any LanguageModel
//

// checked in the ios 27.2 sdk and on developer.apple.com in nov 2026
// LanguageModel is a protocol with capabilities like vision guidedGeneration toolCalling and any of them can drive a LanguageModelSession
// a photo goes in a Prompt as an Attachment next to the text
// the vision ocr tool from the wwdc26 talk is not in the 27.2 sdk so no tool is passed yet
// PrivateCloudComputeLanguageModel has vision and guided answers with a daily quota and SystemLanguageModel has 8192 tokens so the phone reads piece by piece

import Foundation
import FoundationModels
import os
import UIKit

// reads papers with any FoundationModels model
struct ModelPlanReader: PlanReader {

    let choice: ModelChoice
    let makeModel: () throws -> any LanguageModel

    var name: String { choice.displayName }
    var isAvailable: Bool { (try? makeModel()) != nil }

    // same answer every time for the same page
    private static let options = GenerationOptions(samplingMode: .greedy)

    func readPlan(from pages: [String], pictures: [Data?], paper: PaperKind) async throws -> DraftPlan {
        let model = try makeModel()
        let photos = pictures.map { $0.flatMap(UIImage.init(data:)) }
        // never quietly drop the photo or the answer form
        if !model.capabilities.contains(.guidedGeneration) {
            throw PlanReaderError.missingAbility(name, "fill in the plan form")
        }
        if photos.contains(where: { $0 != nil }) && !model.capabilities.contains(.vision) {
            throw PlanReaderError.missingAbility(name, "read photos of your papers")
        }
        if let cloud = model as? PrivateCloudComputeLanguageModel, cloud.quotaUsage.isLimitReached {
            throw PlanReaderError.dailyLimitReached
        }

        guard !choice.sendsDataOffPhone else {
            let plan = try await ask(model, pages: Array(pages.enumerated()), photos: photos.compactMap { $0 },
                                     paper: paper, examples: PromptExamples.maxInPrompt)
            return AIPlanConverter.draft(from: [plan], pages: pages, paper: paper)
        }
        let (plans, warnings) = try await askPieces(model, pages: pages, photos: photos, paper: paper)
        var draft = AIPlanConverter.draft(from: plans, pages: pages, paper: paper)
        draft.warnings.insert(contentsOf: warnings, at: 0)
        return draft
    }

    // MARK: - Private

    // one guided generation call, fewer examples are sent when the prompt is too long
    private func ask(_ model: any LanguageModel, pages: [(offset: Int, element: String)], photos: [UIImage],
                     paper: PaperKind, examples: Int) async throws -> AIPlan {
        let session = LanguageModelSession(model: model, instructions: AIPrompt.instructions(for: paper, examples: examples))
        let prompt = Prompt {
            AIPrompt.prompt(paper: paper, pages: pages, hasPhotos: !photos.isEmpty)
            photos.map { Attachment($0) }
        }
        return try await session.respond(to: prompt, generating: AIPlan.self, options: Self.options).content
    }

    // a small context reads one piece of one page at a time then the answers are merged
    private func askPieces(_ model: any LanguageModel, pages: [String], photos: [UIImage?],
                           paper: PaperKind) async throws -> ([AIPlan], [String]) {
        var plans: [AIPlan] = []
        var warnings: [String] = []
        var pieceCount = 0
        for (index, page) in pages.enumerated() {
            let photo = index < photos.count ? photos[index] : nil
            for piece in AIPrompt.pieces(of: page) {
                pieceCount += 1
                do {
                    plans += try await askPiece(model, piece: piece, page: index, photo: photo, paper: paper, splits: 0)
                } catch where Self.canSkip(error) {
                    PlanReaders.log.error("Skipped part of page \(index + 1): \(error.localizedDescription)")
                    let warning = "Part of page \(index + 1) couldn\u{2019}t be read. Check it on the paper yourself."
                    if !warnings.contains(warning) { warnings.append(warning) }
                }
            }
        }
        if plans.isEmpty && pieceCount > 0 { throw PlanReaderError.couldNotRead }
        return (plans, warnings)
    }

    // one piece split in half when it doesnt fit
    private func askPiece(_ model: any LanguageModel, piece: String, page: Int, photo: UIImage?,
                          paper: PaperKind, splits: Int) async throws -> [AIPlan] {
        do {
            return [try await ask(model, pages: [(offset: page, element: piece)], photos: photo.map { [$0] } ?? [],
                                  paper: paper, examples: 1)]
        } catch {
            guard Self.isTooLong(error), splits < 3, piece.count > 400 else { throw error }
            var plans: [AIPlan] = []
            for half in AIPrompt.pieces(of: piece, size: piece.count / 2 + 1) {
                plans += try await askPiece(model, piece: half, page: page, photo: photo, paper: paper, splits: splits + 1)
            }
            return plans
        }
    }

    // errors about one piece's words
    // ios 27 throws LanguageModelError and older paths the deprecated GenerationError so both are checked
    private static func canSkip(_ error: Error) -> Bool {
        if isTooLong(error) { return true }
        switch error {
        case let error as LanguageModelError:
            switch error {
            case .guardrailViolation, .refusal, .unsupportedLanguageOrLocale: return true
            default: return false
            }
        case let error as LanguageModelSession.GenerationError:
            switch error {
            case .guardrailViolation, .refusal, .decodingFailure, .unsupportedLanguageOrLocale: return true
            default: return false
            }
        default:
            return false
        }
    }

    // true when the model said the prompt does not fit
    private static func isTooLong(_ error: Error) -> Bool {
        if case .contextSizeExceeded = error as? LanguageModelError { return true }
        if case .exceededContextWindowSize = error as? LanguageModelSession.GenerationError { return true }
        return false
    }
}
