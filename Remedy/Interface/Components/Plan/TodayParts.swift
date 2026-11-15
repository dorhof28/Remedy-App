//
//  TodayParts.swift
//  Remedy
//
//  small pieces the today screens share in both looks
//

import SwiftUI

// the round to-do check
struct TodayTaskCheck: View {
    let isDone: Bool
    var tone: Tone = .good
    var font: Font = .title2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
            .font(font)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isDone ? tone.color : Color.inactive)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : isDone)
            .accessibilityHidden(true)
    }
}

// how long the done animation waits
enum TodayTiming {
    static func celebrate(reduceMotion: Bool) -> Duration {
        reduceMotion ? .zero : .milliseconds(550)
    }
}
