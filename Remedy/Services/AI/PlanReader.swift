//
//  PlanReader.swift
//  Remedy
//
//  turns redacted pages into a draft plan and picks the ai
//

import Foundation
import os

// anything that can read papers
protocol PlanReader {
    // for Settings "Apple's cloud AI"
    var name: String { get }
    // can it be used right now
    var isAvailable: Bool { get }
    func readPlan(from pages: [String], paper: PaperKind) async throws -> DraftPlan
}

// tries each reader in turn until one works
struct BackupPlanReader: PlanReader {
    let readers: [PlanReader]

    var name: String { readers.first?.name ?? "None" }
    var isAvailable: Bool { !readers.isEmpty }

    func readPlan(from pages: [String], paper: PaperKind) async throws -> DraftPlan {
        var lastError: Error = PlanReaderError.aiUnavailable
        for reader in readers {
            do {
                var draft = try await reader.readPlan(from: pages, paper: paper)
                draft.readBy = reader.name
                PlanReaders.log.info("Read the papers with \(reader.name)")
                return draft
            } catch {
                PlanReaders.log.error("\(reader.name) failed, trying the next one: \(error.localizedDescription)")
                lastError = error
            }
        }
        throw lastError
    }
}

// DEMO ONLY
struct FakePlanReader: PlanReader {
    let name = "Sample answer (demo)"
    let isAvailable = true

    func readPlan(from pages: [String], paper: PaperKind) async throws -> DraftPlan {
        try await Task.sleep(for: .seconds(2))
        return SampleDrafts.draft(for: paper, pages: pages)
    }
}

// which reader to use
enum PlanReaders {

    // logs which AI ran in Xcode's console
    static let log = Logger(subsystem: "Remedy", category: "AI")

    // best first
    static var ranked: [PlanReader] {
        [ApplePlanReader(model: .cloud), GeminiPlanReader(), ApplePlanReader(model: .phone)]
    }

    // the one the app uses
    static var current: PlanReader {
        if LaunchOptions.usesFakeAI { return FakePlanReader() }
        let ready = ranked.filter { $0.isAvailable }
        if ready.isEmpty && LaunchOptions.isDemo { return FakePlanReader() }
        return BackupPlanReader(readers: ready)
    }
}

// what goes wrong when reading papers in words the patient understands
enum PlanReaderError: LocalizedError {
    case aiUnavailable
    case dailyLimitReached
    case couldNotRead
    case keyRejected
    case busy
    case offline

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
        }
    }
}
