//
//  CheckInTimePrompt.swift
//  Remedy
//
//  the one-time ask on Today for a daily check-in time, once on the first open from surgery day
//  and once more two days after a Not now, never again after that
//

import SwiftUI
import SwiftData

// asks once for a check-in time when the plan has none
struct CheckInTimePromptModifier: ViewModifier {
    let plan: CarePlan?
    var simple = false

    @Environment(\.modelContext) private var context
    @State private var isShowing = false

    private var model: CheckInViewModel { CheckInViewModel(plan: plan, now: AppClock.now()) }

    private static var forced: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "demoCheckInPrompt")
        #else
        return false
        #endif
    }

    func body(content: Content) -> some View {
        content
            .task(id: plan?.persistentModelID) {
                // DEBUG launch argument forces it for screenshots
                // demo plans are for showing people, so the ask stays out of the way
                let isDemo = LaunchOptions.isDemoMode || LaunchOptions.demoScenario != nil
                if (model.shouldPromptForTime && !isDemo) || (Self.forced && plan?.checkInMinute == nil) {
                    try? await Task.sleep(for: .milliseconds(600))
                    isShowing = true
                }
            }
            .sheet(isPresented: $isShowing) {
                CheckInTimeSheet(current: nil, isPrompt: true, simple: simple,
                                 onSave: { minute in
                                     model.setTime(minute, in: context)
                                     isShowing = false
                                 },
                                 onNotNow: {
                                     model.dismissTimePrompt(in: context)
                                     isShowing = false
                                 })
                    // sized to the wheel and buttons, can still grow for large text
                    .presentationDetents([.fraction(simple ? 0.78 : 0.7), .large])
                    .interactiveDismissDisabled()
            }
    }
}

extension View {
    // put on Today in both looks
    func checkInTimePrompt(plan: CarePlan?, simple: Bool = false) -> some View {
        modifier(CheckInTimePromptModifier(plan: plan, simple: simple))
    }
}
