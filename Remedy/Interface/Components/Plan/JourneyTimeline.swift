//
//  JourneyTimeline.swift
//  Remedy
//
//  the whole journey as one line of time: a dot per key day, the date, what happens
//

import SwiftUI

// the plan's stops from before surgery to the end, tap one to open its day
struct JourneyTimeline: View {
    let rows: [JourneyStopRow]
    var large = false
    let onPick: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                Button {
                    onPick(row.stop.day)
                } label: {
                    JourneyStopView(row: row, isFirst: row.id == rows.first?.id, isLast: row.id == rows.last?.id, large: large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.spokenLabel)
                .accessibilityHint("Shows this day")
            }
        }
        .padding(.horizontal, large ? 12 : 8)
        .padding(.vertical, 8)
        .cardStyle()
    }
}

// one key day: the dot on the line, the date and what happens
struct JourneyStopView: View {
    let row: JourneyStopRow
    let isFirst: Bool
    let isLast: Bool
    var large = false

    @ScaledMetric(relativeTo: .subheadline) private var dateWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var dot: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // the line of time and the dot
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle().fill(isFirst ? Color.clear : Color.hairline).frame(width: 2, height: 16)
                    Rectangle().fill(isLast ? Color.clear : Color.hairline).frame(width: 2).frame(maxHeight: .infinity)
                }
                mark.padding(.top, 16 - dot / 2)
            }
            .frame(width: dot + 6)

            Text(row.dateText)
                .font(large ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(row.isToday ? Color.accentInk : Color.ink2)
                .frame(width: large ? dateWidth * 1.3 : dateWidth, alignment: .leading)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.titleText)
                    .font(large ? .title3.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(row.isSurgery ? Color.secondInk : Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !row.secondLine.isEmpty {
                    Text(row.secondLine)
                        .font(large ? .body : .subheadline)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(minHeight: large ? Spacing.tapSimple : Spacing.tapMin)
        .background {
            if row.isToday {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.accentSoft)
            }
        }
        .contentShape(Rectangle())
    }

    // done filled, surgery pink, today a ring, later an open circle
    @ViewBuilder
    private var mark: some View {
        if row.isSurgery {
            Circle().fill(row.isFaded ? Color.secondInk : Color.secondSoft).frame(width: dot, height: dot)
                .overlay(Circle().strokeBorder(Color.secondInk, lineWidth: 3))
        } else if row.isToday {
            Circle().fill(Color.surface).frame(width: dot, height: dot)
                .overlay(Circle().strokeBorder(Color.accentInk, lineWidth: 3))
        } else if row.isFaded {
            Circle().fill(Color.accentInk).frame(width: dot, height: dot)
        } else {
            Circle().fill(Color.surface).frame(width: dot, height: dot)
                .overlay(Circle().strokeBorder(Color.ink3, lineWidth: 2))
        }
    }
}
