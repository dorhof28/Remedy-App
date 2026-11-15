//
//  RemindersRefresher.swift
//  Remedy
//
//  keeps notifications and the widget up to date
//

import SwiftUI
import SwiftData

// the key that says when reminders need a redo
enum RemindersKey {
    // stable text of everything reminders depend on
    static func make(for plan: CarePlan?) -> String {
        guard let plan else { return "none" }
        // stable text of every medicine name and time (hashValue changes each launch)
        let medicines = plan.medicines
            .map { "\($0.name)@\($0.timesOfDay.map(String.init).joined(separator: ","))" }
            .sorted()
            .joined(separator: "|")
        return "\(plan.createdAt.timeIntervalSince1970)-\(plan.surgeryDate?.timeIntervalSince1970 ?? 0)-\(plan.medicines.count)-\(plan.appointments.count)-\(plan.tasks.count)-\(plan.checkInMinute ?? -1)-\(medicines)"
    }
}

// redoes reminders, the widget and the live activity whenever the key changes
struct RemindersRefresher: ViewModifier {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.scenePhase) private var scenePhase

    // changes whenever something that affects reminders changes
    private var planKey: String {
        RemindersKey.make(for: plans.first)
    }

    func body(content: Content) -> some View {
        content
            .task(id: planKey) {
                await NotificationService.shared.refresh(plan: plans.first, now: AppClock.now())
                WidgetSnapshotMaker.save(plan: plans.first, now: AppClock.now())
                await LiveActivityManager.sync(plan: plans.first, now: AppClock.now())
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .inactive else { return }
                Task { await NotificationService.shared.refresh(plan: plans.first, now: AppClock.now()) }
                WidgetSnapshotMaker.save(plan: plans.first, now: AppClock.now())    // the Home Screen widget
                Task { await LiveActivityManager.sync(plan: plans.first, now: AppClock.now()) }
            }
    }
}

extension View {
    // put on rootview once
    func keepsRemindersUpToDate() -> some View {
        modifier(RemindersRefresher())
    }
}
