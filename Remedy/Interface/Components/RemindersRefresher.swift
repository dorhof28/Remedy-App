//
//  RemindersRefresher.swift
//  Remedy
//
//  keeps notifications and the widget up to date
//

import SwiftUI
import SwiftData

struct RemindersRefresher: ViewModifier {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.scenePhase) private var scenePhase

    // changes whenever something that affects reminders changes
    private var planKey: String {
        guard let plan = plans.first else { return "none" }
        return "\(plan.surgeryDate?.timeIntervalSince1970 ?? 0)-\(plan.medicines.count)-\(plan.appointments.count)-\(plan.tasks.count)"
    }

    func body(content: Content) -> some View {
        content
            .task(id: planKey) {
                await NotificationService.shared.refresh(plan: plans.first, now: AppClock.now())
                WidgetSnapshotMaker.save(plan: plans.first, now: AppClock.now())
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .inactive else { return }
                Task { await NotificationService.shared.refresh(plan: plans.first, now: AppClock.now()) }
                WidgetSnapshotMaker.save(plan: plans.first, now: AppClock.now())    // the Home Screen widget
            }
    }
}

extension View {
    // put on rootview once
    func keepsRemindersUpToDate() -> some View {
        modifier(RemindersRefresher())
    }
}
