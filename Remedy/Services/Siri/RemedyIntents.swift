//
//  RemedyIntents.swift
//  Remedy
//
//  siri and shortcuts
//

import AppIntents
import Foundation
import SwiftData

// "What do I take?"
nonisolated struct WhatToTakeIntent: AppIntent {
    static let title: LocalizedStringResource = "What do I take now?"
    static let description = IntentDescription("Says what Remedy shows on Today: what to take, or what to stop.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let today = SiriToday.load() else {
            return .result(dialog: "You don\u{2019}t have a plan yet. Open Remedy and scan your papers.")
        }
        return .result(dialog: "\(today.spokenSummary)")
    }
}

// "I took my medicine"
nonisolated struct TookMedicineIntent: AppIntent {
    static let title: LocalizedStringResource = "I took my medicine"
    static let description = IntentDescription("Marks the medicines that are due now as taken.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let today = SiriToday.load(), today.nowCard.showsButtons else {
            return .result(dialog: "Nothing is due right now, so I didn\u{2019}t mark anything.")
        }
        let taken = today.nowCard.title
        _ = today.takeNow(in: RemedyApp.shared.mainContext)
        return .result(dialog: "Got it. I marked \(taken) as taken.")
    }
}

// the phrases Siri listens for
nonisolated struct RemedyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WhatToTakeIntent(),
                    phrases: ["What do I take in \(.applicationName)",
                              "Ask \(.applicationName) what to take",
                              "What does \(.applicationName) say for today"],
                    shortTitle: "What to take",
                    systemImageName: "pills")
        AppShortcut(intent: TookMedicineIntent(),
                    phrases: ["I took my medicine in \(.applicationName)",
                              "Log my medicine in \(.applicationName)",
                              "Mark my pills as taken in \(.applicationName)"],
                    shortTitle: "I took it",
                    systemImageName: "checkmark.circle")
    }
}

// today worked out the same way the Today screen does it
private enum SiriToday {
    // today from the newest plan
    @MainActor
    static func load() -> TodayViewModel? {
        let newestFirst = FetchDescriptor<CarePlan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let plan = try? RemedyApp.shared.mainContext.fetch(newestFirst).first else { return nil }
        return TodayViewModel(plan: plan, now: AppClock.now())
    }
}
