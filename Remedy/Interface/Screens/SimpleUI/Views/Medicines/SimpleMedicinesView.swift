//
//  SimpleMedicinesView.swift
//  Remedy
//
//  simple medicines overview and groups
//

import SwiftUI
import SwiftData

struct SimpleMedicinesView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = MedicinesViewModel(plan: plans.first, now: AppClock.now())
            SimpleScreen(title: "My medicines") {
                if viewModel.isEmpty {
                    Text(viewModel.emptyDetail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.simpleGroups) { group in
                    NavigationLink(value: SimpleRoute.medicineGroup(group.id)) {
                        SimpleGroupButton(group: group)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - One group, page by page

// one group of medicines
struct SimpleMedicineGroupView: View {
    let groupID: String

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = MedicinesViewModel(plan: plans.first, now: AppClock.now())
            SimpleScreen(title: viewModel.groupTitle(groupID)) {
                SimplePagedList(items: viewModel.rows(inGroup: groupID), perPage: 4) { row in
                    NavigationLink(value: row.medicine) {
                        SimpleRowCard(title: row.title, subtitle: row.subtitle, status: row.trailingLine, tone: row.tone) {
                            MedicineIcon(pillShape: row.pillShape, pillColor: row.pillColor,
                                         symbol: row.symbol, tone: row.tone, size: 48)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.spokenLabel)
                }
            }
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleMedicinesView() }
}
