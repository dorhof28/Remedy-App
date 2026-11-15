//
//  ConnectionCheck.swift
//  Remedy
//
//  checks mychart and apple health are working before a demo
//

import Foundation
import os

// one line of the check
struct ConnectionResult: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isOK: Bool
    // which row of check connections (109) it belongs to
    var source: Source = .other

    enum Source { case myChart, health, other }
}

// checks mychart and health answer before a demo
enum ConnectionCheck {

    // every check in order
    static func run() async -> [ConnectionResult] {
        var results: [ConnectionResult] = []

        // mychart
        results.append(ConnectionResult(title: "MyChart client ID",
                                        detail: EpicConfig.isSetUp ? "Set (Epic sandbox)" : "Missing in EpicConfig",
                                        isOK: EpicConfig.isSetUp, source: .myChart))
        var server = await epicServer()
        server.source = .myChart
        results.append(server)

        // apple health
        results.append(ConnectionResult(title: "Health on this device",
                                        detail: HealthService.isAvailable ? "Available" : "Not available here",
                                        isOK: HealthService.isAvailable, source: .health))
        results.append(ConnectionResult(title: "Health Records",
                                        detail: HealthService.canReadRecords ? "Supported" : "Not supported on this device",
                                        isOK: HealthService.canReadRecords, source: .health))
        if HealthService.canReadRecords {
            do {
                let records = try await HealthService.medicineRecords()
                results.append(ConnectionResult(title: "Medicine records",
                                                detail: records.isEmpty ? "None yet. Add a hospital in the Health app" : "\(records.count) found",
                                                isOK: !records.isEmpty, source: .health))
            } catch {
                results.append(ConnectionResult(title: "Medicine records", detail: "Permission not given", isOK: false, source: .health))
            }
        }

        // gemini
        results.append(ConnectionResult(title: "Gemini key",
                                        detail: GeminiPlanReader().isAvailable ? "Saved in the Keychain" : "Not saved",
                                        isOK: GeminiPlanReader().isAvailable))
        return results
    }

    // can we reach epic's sign in details
    private static func epicServer() async -> ConnectionResult {
        let url = EpicConfig.fhirBase.appending(path: ".well-known/smart-configuration")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let status = (try? await FHIRClient.session.data(for: request)).flatMap { ($0.1 as? HTTPURLResponse)?.statusCode } ?? 0
        return ConnectionResult(title: "Epic sandbox server",
                                detail: status == 200 ? "Reachable" : "Can\u{2019}t reach it (\(status))",
                                isOK: status == 200)
    }
}
