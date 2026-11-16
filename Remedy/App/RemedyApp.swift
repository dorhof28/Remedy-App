//
//  RemedyApp.swift
//  Remedy
//
//  Created by Dorron Hoffman on 5/24/26.
//
//  app start opens the database and shows rootview
//

import SwiftUI
import SwiftData

// app opens the database and shows the root view
@main
struct RemedyApp: App {

    // database
    let container: ModelContainer = RemedyApp.shared

    // the one database shared with Siri
    static let shared: ModelContainer = makeContainer()

    init() {
        // lets the "I took it" button on a notification save to the database
        NotificationService.shared.start(container: container)
    }

    var body: some Scene {
        WindowGroup {
            DemoClockRoot()
                .textFieldStyle(RemedyTextFieldStyle())
        }
        .modelContainer(container)
    }

    // normal run saves to the phone
    static func makeContainer() -> ModelContainer {
        let schema = Schema(RemedySchema.models)
        let inMemory = LaunchOptions.isDemo
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)

            if let scenario = LaunchOptions.demoScenario, !LaunchOptions.startsEmpty {
                // papers with fixed dates turn demo mode on so the pretend clock can reach their day
                if scenario.fixedSurgery(today: Date()) != nil {
                    DemoMode.turnOn()
                    DemoMode.setClock(for: scenario, day: LaunchOptions.demoPlanDay)
                }
                DemoMode.insert(scenario, into: container.mainContext)
            } else if LaunchOptions.usesSamplePlan && !LaunchOptions.startsEmpty {
                // demoDay -4 means surgery is 4 days from today
                SamplePlan.insert(into: container.mainContext, surgeryInDays: -LaunchOptions.demoDay)
                // made up patient name so family share shows one
                if PatientNames.saved.isEmpty { PatientNames.save(SamplePlan.patientName) }
            }
            return container
        } catch { 
            // only happens if the models are broken so crash loudly while building
            fatalError("Could not open the database: \(error)")
        }
    }
}

// the app redraws from the top after the Demo mode clock moved, so every screen reads the new fake today
private struct DemoClockRoot: View {
    @State private var stamp = 0

    var body: some View {
        RootView()
            .keepsRemindersUpToDate()
            .id(stamp)
            .onReceive(NotificationCenter.default.publisher(for: .demoClockChanged)) { _ in stamp += 1 }
    }
}
