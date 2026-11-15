//
//  PlanSync.swift
//  Remedy
//
//  after a medicine or visit changes, reminders widget and calendar follow
//

import Foundation

// keeps reminders, widgets and the calendar in step with the plan
@MainActor
enum PlanSync {

    // redo reminders now, the plan screens also redo them when counts change
    static func refresh(_ plan: CarePlan?) {
        let now = AppClock.now()
        Task {
            await NotificationService.shared.refresh(plan: plan, now: now)
            WidgetSnapshotMaker.save(plan: plan, now: now)
            await LiveActivityManager.sync(plan: plan, now: now)
            if UserDefaults.standard.bool(forKey: CalendarService.planOnKey) {
                await CalendarService.syncPlan(plan)
            }
        }
    }
}
