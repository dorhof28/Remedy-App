//
//  ConnectionCheckViewModel.swift
//  Remedy
//
//  runs the mychart and health check for settings
//

import Foundation
import Observation

// the check connections page, test builds only
@Observable
final class ConnectionCheckViewModel {

    var results: [ConnectionResult] = []
    var isRunning = false

    let title = "Check connections"
    let footer = "To test MyChart, sign in to Epic\u{2019}s test hospital with the username fhircamila and the password epicepic1. To test Health Records on the Simulator, open the Health app, go to Browse, then Health Records, and add a sample hospital."

    // MARK: - 109 one row each for mychart and health

    let pageTitle = "Check Connections"
    let checkAgainTitle = "Check Again"
    let checkingText = "Checking\u{2026}"
    let pageFooter = "Checks sign-in and reading only. Nothing is saved to your plan."

    struct SourceRow: Identifiable {
        let title: String
        let isOK: Bool
        let detail: String
        var id: String { title }
    }

    var sourceRows: [SourceRow] {
        [row("MyChart", .myChart, passed: "test hospital reachable"),
         row("Apple Health", .health, passed: "health records read")]
    }

    // "Passed · test hospital reachable" or "Failed · none yet. add a hospital in the health app"
    private func row(_ title: String, _ source: ConnectionResult.Source, passed: String) -> SourceRow {
        let mine = results.filter { $0.source == source }
        if let failed = mine.first(where: { !$0.isOK }) {
            return SourceRow(title: title, isOK: false, detail: "Failed \u{00B7} \(Self.lowerFirst(failed.detail))")
        }
        return SourceRow(title: title, isOK: !mine.isEmpty, detail: mine.isEmpty ? "" : "Passed \u{00B7} \(passed)")
    }

    private static func lowerFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }

    func run() async {
        isRunning = true
        results = await ConnectionCheck.run()
        isRunning = false
    }
}
