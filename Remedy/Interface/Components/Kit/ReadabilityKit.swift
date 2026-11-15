//
//  ReadabilityKit.swift
//  Remedy
//
//  shared pieces that make rows and headers easy to skim
//

import SwiftUI

// a second line whose leading time is semibold so times pop, in the line's tone
struct DetailLine: View {
    let text: String
    var tone: Tone = .neutral
    var font: Font = .subheadline

    var body: some View {
        let parts = ReadabilityWords.splitLeadingTime(text)
        let color = tone == .neutral ? Color.ink2 : tone.color
        Group {
            if parts.lead.isEmpty {
                Text(text)
            } else {
                Text("\(Text(parts.lead).fontWeight(.semibold).foregroundStyle(tone == .neutral ? Color.ink : tone.color))\(parts.rest)")
            }
        }
        .font(font)
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// a small tinted pill, for counts beside a header
struct CountPill: View {
    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(tone == .neutral ? Color.surface2 : tone.soft))
    }
}

// one icon kind for each kind of my day card, so tiles match the classic look
extension SimpleDayItem.Kind {
    func itemKind(goalSymbol: String?) -> ItemKind {
        switch self {
        case .dose: return .medicine
        case .asNeeded: return .asNeeded
        case .visit: return .visit
        case .todo: return .todo
        case .checkIn: return .checkIn
        case .goal: return .goal(symbol: goalSymbol ?? "figure.walk")
        case .stop: return .paused
        case .fillIn: return .paper
        case .surgery: return .surgery
        case .rule: return .custom(symbol: "hand.raised", tone: .caution)
        }
    }
}
