//
//  NextUpAccessory.swift
//  Remedy
//
//  glass bar above the tabs with the next thing to do
//

import SwiftUI
import SwiftData

struct NextUpAccessory: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        TimelineView(.everyMinute) { _ in
            if let plan = plans.first {
                let line = WidgetSnapshotMaker.current(plan: plan, now: AppClock.now())
                HStack(spacing: 10) {
                    Image(systemName: line.symbol)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.eyebrow)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(line.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
