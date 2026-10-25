//
//  RemedyApp.swift
//  Remedy
//
//  Created by Dorron Hoffman on 10/24/26.
//
//  app start opens the database and shows rootview
//

import SwiftUI
import SwiftData

@main
struct RemedyApp: App {

    // database
    let container: ModelContainer = RemedyApp.shared

    // the one database shared with Siri
    static let shared: ModelContainer = makeContainer()

    init() {
        // lets the "I took it" button on a notification save to the database
        NotificationService.shared.start(container: container)
        // gemini key from a private xcode scheme
        GeminiPlanReader.saveKeyFromXcode()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .keepsRemindersUpToDate()
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

            if LaunchOptions.usesSamplePlan && !LaunchOptions.startsEmpty {
                // demoDay -4 means surgery is 4 days from today
                SamplePlan.insert(into: container.mainContext, surgeryInDays: -LaunchOptions.demoDay)
            }
            return container
        } catch {
            // only happens if the models are broken so crash loudly while building
            fatalError("Could not open the database: \(error)")
        }
    }
}
