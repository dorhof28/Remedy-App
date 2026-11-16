//
//  DemoPatient.swift
//  Remedy
//
//  demo mode: loads a fake plan and keeps the real one safe
//

import Foundation
import SwiftData

// MARK: - Demo mode from Settings

// where the real plan waits while a fake one is on screen
struct DemoBackupStore {

    let url: URL

    // the app's own folder, kept on this phone only
    // an in-memory database from the scheme gets its own copy so it never meets the real plan's copy
    static var live: DemoBackupStore {
        let folder = LaunchOptions.isDemo ? FileManager.default.temporaryDirectory
            : (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return DemoBackupStore(url: folder.appendingPathComponent("Remedy", isDirectory: true)
            .appendingPathComponent("DemoBackup.json"))
    }

    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    // writes the copy then reads it back, so the real plan is only touched once the copy is proven
    func save(_ snapshot: BackupSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        guard try load() == snapshot else { throw DemoModeError.backupNotSaved }
    }

    // nil when there is no copy
    func load() throws -> BackupSnapshot? {
        guard exists else { return nil }
        return try JSONDecoder().decode(BackupSnapshot.self, from: Data(contentsOf: url))
    }

    // removes the saved copy of the real plan
    func delete() throws {
        if exists { try FileManager.default.removeItem(at: url) }
    }
}

// the real plan could not be put aside, so demo mode does not start
enum DemoModeError: Error, Equatable {
    case backupNotSaved
}

// turning demo mode on, loading a fake plan and getting the real one back
enum DemoMode {

    // plan, doses, chat and photos of the real patient go in the copy first, then everything is replaced
    // switching between fake plans keeps the first copy so the real plan is never overwritten by fake data
    static func load(_ scenario: DemoScenario, into context: ModelContext, store: DemoBackupStore = .live,
                     defaults: UserDefaults = .standard) throws {
        if !store.exists {
            try store.save(try BackupSnapshot.make(from: context))
        }
        // the fake clock starts at today before the plan is made, so its past days are filled up to now
        defaults.set(0, forKey: LaunchOptions.demoShiftKey)
        do {
            for type in RemedySchema.models { try deleteAll(type, in: context) }
            insert(scenario, into: context)
            try context.save()
        } catch {
            // nothing half done, the old plan stays
            context.rollback()
            throw error
        }
        defaults.set(true, forKey: LaunchOptions.demoModeKey)
        defaults.set(0, forKey: LaunchOptions.demoShiftKey)
        defaults.set(scenario.title, forKey: LaunchOptions.demoLoadedKey)
    }

    // puts the saved copy back all or nothing, only then the copy is deleted
    static func exit(into context: ModelContext, store: DemoBackupStore = .live, defaults: UserDefaults = .standard) throws {
        if let snapshot = try store.load() {
            try snapshot.restore(into: context)
            try store.delete()
        }
        turnOff(defaults: defaults)
    }

    // the flag every demo check reads
    static func turnOn(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: LaunchOptions.demoModeKey)
    }

    // also resets the fake clock
    static func turnOff(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: LaunchOptions.demoModeKey)
        defaults.set(0, forKey: LaunchOptions.demoShiftKey)
        defaults.removeObject(forKey: LaunchOptions.demoLoadedKey)
        defaults.removeObject(forKey: LaunchOptions.demoExpectedAnswersKey)
    }

    // moves the fake today by whole days, never past a year either way
    @discardableResult
    static func moveToday(byDays days: Int, defaults: UserDefaults = .standard) -> Int {
        let next = LaunchOptions.clampedShift(defaults.integer(forKey: LaunchOptions.demoShiftKey) + days)
        defaults.set(next, forKey: LaunchOptions.demoShiftKey)
        return next
    }

    // the fake plan itself, every paper confirmed so rules, to-dos and visits are saved too
    @discardableResult
    static func insert(_ scenario: DemoScenario, into context: ModelContext) -> CarePlan? {
        let today = DayMath.calendar.startOfDay(for: Date())
        switch scenario.build(today: today) {
        case .samplePlan(let days):
            SamplePlan.insert(into: context, surgeryInDays: days)
            return PlanActions.currentPlan(in: context)
        case .papers(let drafts):
            var plan: CarePlan?
            for var draft in drafts {
                draft.isSample = true
                for index in draft.medicines.indices { draft.medicines[index].isConfirmed = true }
                for index in draft.rules.indices { draft.rules[index].isConfirmed = true }
                for index in draft.tasks.indices { draft.tasks[index].isConfirmed = true }
                for index in draft.appointments.indices { draft.appointments[index].isConfirmed = true }
                plan = PlanImporter.save(draft, in: context)
            }
            // the HSS papers come with the days already lived, doses, pain pills and check-ins
            if scenario == .hssKnee, let plan { DemoHistory.fill(plan, now: AppClock.now(), in: context) }
            return plan
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) { context.delete(model) }
    }
}
