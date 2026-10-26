//
//  JourneyTimeline.swift
//  Remedy
//
//  the whole journey as a timeline with dates icons and a rail
//

import SwiftUI

struct JourneyTimeline: View {
    let rows: [JourneyStopRow]
    let onPick: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                Button {
                    onPick(row.stop.day)
                } label: {
                    JourneyStopView(row: row, isFirst: row.id == rows.first?.id, isLast: row.id == rows.last?.id)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.spokenLabel)
                .accessibilityHint("Shows this day")
            }
        }
    }
}

// one key day date tile rail icon and what happens
struct JourneyStopView: View {
    let row: JourneyStopRow
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // date tile
            VStack(spacing: 0) {
                Text(row.stop.month)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(row.tone.color)
                Text(row.stop.dayNumber)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(row.stop.weekday)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)
            .padding(.vertical, 6)
            .opacity(row.isFaded ? 0.5 : 1)

            // rail and icon
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : railAbove)
                        .frame(width: 3, height: 14)
                    Rectangle()
                        .fill(isLast ? Color.clear : railBelow)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
                Image(systemName: row.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(row.isFaded ? Color.secondary : .white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(row.isFaded ? Color.tileBackground : row.tone.color))
                    .overlay {
                        if row.stop.state == .today {
                            Circle().strokeBorder(Color.remedyTeal, lineWidth: 3).padding(-5)
                        }
                    }
                    .padding(.top, 6)
            }
            .frame(width: 40)

            // what happens
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.labelText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(row.tone.color)
                    if !row.stateText.isEmpty {
                        Text(row.stateText)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(row.tone.color.opacity(0.15)))
                            .foregroundStyle(row.tone.color)
                    }
                }
                ForEach(row.stop.titles, id: \.self) { title in
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(row.isFaded ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
    }

    // the path walked so far is filled in
    private var railAbove: Color {
        row.stop.state == .done || row.stop.state == .today ? .remedyTeal : .tileBackground
    }

    private var railBelow: Color {
        row.stop.state == .done ? .remedyTeal : .tileBackground
    }
}
