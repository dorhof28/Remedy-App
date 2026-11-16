//
//  PlanReader.swift
//  Remedy
//
//  turns redacted pages into a draft plan with the ai the patient picked
//

import Foundation
import os
import FoundationModels

// anything that can read papers
protocol PlanReader {
    // for Settings "Claude"
    var name: String { get }
    // can it be used right now
    var isAvailable: Bool { get }
    // pictures line up with pages and are only the blacked out jpegs that may be sent
    func readPlan(from pages: [String], pictures: [Data?], paper: PaperKind) async throws -> DraftPlan
}

// DEMO ONLY
struct FakePlanReader: PlanReader {
    let name = "Sample answer (demo)"
    let isAvailable = true

    // waits like a real reader so the reading screen shows
    func readPlan(from pages: [String], pictures: [Data?], paper: PaperKind) async throws -> DraftPlan {
        try await Task.sleep(for: .seconds(2))
        return SampleDrafts.draft(for: paper, pages: pages)
    }
}

// DEMO ONLY the answer key for the sample papers, anything else is an error never an ai
struct ExpectedAnswerReader: PlanReader {
    let name = "Expected answers (demo)"
    let isAvailable = true

    func readPlan(from pages: [String], pictures: [Data?], paper: PaperKind) async throws -> DraftPlan {
        try await Task.sleep(for: .seconds(2))
        return try Self.answer(for: pages)
    }

    // the sample paper's answer with these pages attached
    static func answer(for pages: [String]) throws -> DraftPlan {
        guard var draft = SamplePatients.draft(matching: pages) else { throw PlanReaderError.notASamplePaper }
        draft.pages = pages.enumerated().map { DraftPage(pageNumber: $0.offset + 1, redactedText: $0.element) }
        return draft
    }
}

// which reader to use
enum PlanReaders {

    // logs which AI ran in Xcode's console
    static let log = Logger(subsystem: "Remedy", category: "AI")

    // the one place a choice becomes a reader
    // a new provider is one adapter file one ModelChoice entry and one case here
    static func reader(for choice: ModelChoice) -> PlanReader {
        if LaunchOptions.usesFakeAI { return FakePlanReader() }
        if LaunchOptions.usesExpectedAnswers { return ExpectedAnswerReader() }
        let reader: PlanReader
        switch choice.id {
        case .onPhone:
            reader = ModelPlanReader(choice: choice) {
                guard AppleAI.isPhoneAvailable else { throw PlanReaderError.aiUnavailable }
                return SystemLanguageModel.default
            }
        case .applePrivateCloud:
            reader = ModelPlanReader(choice: choice) {
                guard AppleAI.isCloudAvailable else { throw PlanReaderError.notReady(choice.displayName) }
                return PrivateCloudComputeLanguageModel()
            }
        case .claude: reader = ModelPlanReader(choice: choice, makeModel: { try ClaudeAdapter.model() })
        case .openAI, .yourMac, .openRouter, .groq, .mistral, .openAICompatible:
            reader = ModelPlanReader(choice: choice) { try OpenAICompatibleAdapter.model(for: choice) }
        case .gemini: reader = GeminiPlanReader()
        }
        // DEMO ONLY the demo schemes still show a plan without any ai
        if LaunchOptions.isDemo && !reader.isAvailable { return FakePlanReader() }
        return reader
    }

    // the planner the patient picked
    static var current: PlanReader { reader(for: ModelSettings.load().plannerChoice) }
}

// what goes wrong when reading papers in words the patient understands
enum PlanReaderError: LocalizedError {
    case aiUnavailable
    case dailyLimitReached
    case couldNotRead
    case keyRejected
    case busy
    case offline
    case notReady(String)               // the picked ai has no key or isn't on this phone
    case missingAbility(String, String) // the picked ai can't read photos or fill in the answer form
    case notASamplePaper                // demo expected answers only know the sample papers

    var errorDescription: String? {
        switch self {
        case .aiUnavailable:
            return "Reading papers needs Apple Intelligence (Settings app \u{2192} Apple Intelligence & Siri) or an AI key in Remedy\u{2019}s Settings."
        case .dailyLimitReached:
            return "You\u{2019}ve reached today\u{2019}s limit for reading papers. Try again tomorrow."
        case .couldNotRead:
            return "We couldn\u{2019}t read these pages. Try scanning again in good light, with the whole page in view."
        case .keyRejected:
            return "The Gemini key in Settings didn\u{2019}t work. Check it and try again."
        case .busy:
            return "The AI is busy right now. Wait a minute and try again."
        case .offline:
            return "You\u{2019}re offline. Check your internet and try again."
        case .notReady(let name):
            return "\(name) isn\u{2019}t set up on this phone yet. Pick another AI in Settings."
        case .missingAbility(let name, let ability):
            return "\(name) can\u{2019}t \(ability). Pick another AI in Settings."
        case .notASamplePaper:
            return "This isn\u{2019}t one of the sample papers, so there\u{2019}s no expected answer for it. To read it with AI, go to Demo Mode and set Read papers with to Your AI."
        }
    }
}
