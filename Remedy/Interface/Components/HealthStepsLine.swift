//
//  HealthStepsLine.swift
//  Remedy
//
//  steps from apple health under the daily goals
//

import SwiftUI

struct HealthStepsLine: View {
    @AppStorage(HealthService.stepsOnKey) private var isOn = false
    @State private var text: String?

    var body: some View {
        Label(text ?? "", systemImage: "figure.walk")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .opacity(text == nil ? 0 : 1)
            .frame(height: text == nil ? 0 : nil)
            .task(id: isOn) {
                text = isOn ? await HealthService.stepsTodayText(now: AppClock.now()) : nil
            }
    }
}
