//
//  LiveActivityManager.swift
//  Remedy
//
//  starts, updates and ends the busy-day Live Activity
//

import ActivityKit
import Foundation
import SwiftData

// ids the patient ticked today
enum ChecklistStore {
    private static let key = "remedy.checklist.checked"

    // ticks are kept per calendar day so tomorrow starts clear
    private static func dayKey(_ now: Date) -> String {
        let parts = DayMath.calendar.dateComponents([.year, .month, .day], from: now)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    // the checklist rows ticked today on the live activity
    static func checked(now: Date) -> Set<String> {
        let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]]
        return Set(saved?[dayKey(now)] ?? [])
    }

    static func setChecked(_ id: String, _ done: Bool, now: Date) {
        var ids = checked(now: now)
        if done { ids.insert(id) } else { ids.remove(id) }
        // keep only today
        UserDefaults.standard.set([dayKey(now): Array(ids)], forKey: key)
    }
}

// starts, updates or ends the busy day live activity
@MainActor
enum LiveActivityManager {

    // makes the activity match the plan right now
    static func sync(plan: CarePlan?, now: Date) async {
        var running = Activity<RemedyActivityAttributes>.activities
        // a plan whose context is gone cannot be read
        if let plan, plan.modelContext == nil { return }
        guard let plan, let today = DoseSchedule.today(for: plan, now: now),
              DayChecklist.isBusy(day: today, plan: plan, skipped: PaperCheckReport.of(plan).skipped) else {
            for activity in running { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let items = DayChecklist.items(plan: plan, day: today, now: now, checked: ChecklistStore.checked(now: now),
                                   skipped: PaperCheckReport.of(plan).skipped)
        guard !items.isEmpty else {
            for activity in running { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let next = DayChecklist.next(in: items)
        var headline = next.map { $0.time == nil ? "Next: \($0.title)" : $0.title } ?? "All done for now"
        var countdown: Date?
        if let next, let time = next.time, time > now {
            countdown = time
            headline = next.title == "Last clear liquids" ? "Clear liquids end in" : "\(next.title) in"
        }
        // surgery morning reads like screen 29, the arrival time and what not to eat or drink
        var detail: String?
        var headlineOnly: Bool?
        if today == 0, let morning = SurgeryMorningWords.headline(arrival: DayChecklist.arrival(for: plan)) {
            let texts = plan.rules.flatMap { [$0.title, $0.quote] }
            let surgery = plan.surgeryDate ?? now
            headline = morning
            countdown = nil
            detail = SurgeryMorningWords.detail(liquidsEnd: FastingTimes.clearLiquidsEnd(arrival: DayChecklist.arrival(for: plan), texts: texts),
                                                hasFoodRule: FastingTimes.foodStop(surgeryDate: surgery, texts: texts) != nil, now: now)
            headlineOnly = true
        }
        let state = RemedyActivityAttributes.ContentState(
            headline: headline, countdownTo: countdown,
            steps: items.map { .init(title: $0.title, isDone: $0.isDone) },
            nextTitle: next?.title, doneCount: items.filter(\.isDone).count, totalCount: items.count,
            detail: detail, showsHeadlineOnly: headlineOnly)
        // stale when the countdown ends so the lock screen stops showing 0:00
        let content = ActivityContent(state: state, staleDate: countdown)

        // a new day needs a new title, titles cant change inside a running activity
        let title = today == 0 ? SurgeryMorningWords.title : today == -1 ? "Day before surgery" : "Today"
        for old in running where old.attributes.dayTitle != title { await old.end(nil, dismissalPolicy: .immediate) }
        running = running.filter { $0.attributes.dayTitle == title }

        // one activity only, extras are closed
        for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }

        if next == nil {
            // everything ticked: show it a little while then close, dont start a new one
            if let activity = running.first {
                await activity.end(content, dismissalPolicy: .after(now.addingTimeInterval(30 * 60)))
            }
        } else if let activity = running.first {
            await activity.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            let address = today == 0 ? plan.hospitalAddress : nil
            let attributes = RemedyActivityAttributes(dayTitle: title, directionsAddress: address,
                                                      placeName: today == 0 ? plan.hospitalName : nil)
            _ = try? Activity.request(attributes: attributes, content: content)
        }
    }
}
