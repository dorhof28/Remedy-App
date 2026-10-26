//
//  ConnectionCheckViewModel.swift
//  Remedy
//
//  runs the mychart and health check for settings
//

import Foundation
import Observation

@Observable
final class ConnectionCheckViewModel {

    var results: [ConnectionResult] = []
    var isRunning = false

    let title = "Check connections"
    let runTitle = "Run again"
    let footer = "To test MyChart, sign in to Epic\u{2019}s test hospital with the username fhircamila and the password epicepic1. To test Health Records on the Simulator, open the Health app, go to Browse, then Health Records, and add a sample hospital."

    var passedText: String {
        "\(results.filter(\.isOK).count) of \(results.count) working"
    }

    func run() async {
        isRunning = true
        results = await ConnectionCheck.run()
        isRunning = false
    }
}
