//
//  MedicinesView.swift
//  Remedy
//
//  classic medicines tab
//

import SwiftUI
import SwiftData

struct MedicinesView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    @State private var query = ""

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                let viewModel = MedicinesViewModel(plan: plans.first, now: AppClock.now())
                content(viewModel)
                    .navigationTitle(viewModel.title)
                    .searchable(text: $query, prompt: viewModel.searchPrompt)
                    .helpButtons()
            }
            .background(Color.screenBackground)
            .navigationDestination(for: MedicineInstruction.self) { medicine in
                MedicineDetailView(medicine: medicine)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: MedicinesViewModel) -> some View {
        if viewModel.isEmpty {
            ContentUnavailableView(viewModel.emptyTitle, systemImage: "pills",
                                   description: Text(viewModel.emptyDetail))
        } else {
            ScrollView {
                VStack(spacing: Spacing.betweenCards) {
                    if viewModel.isSearching(query) {
                        SearchResultsCard(viewModel: viewModel, query: query)
                    } else {
                        ForEach(viewModel.sections) { section in
                            SectionCard(title: section.title, symbol: section.symbol,
                                        detail: section.countText, tone: section.tone,
                                        startsExpanded: section.startsExpanded,
                                        rememberAs: "medicines." + section.id) {
                                MedicineRowList(rows: section.rows, viewModel: viewModel)
                                if !section.footer.isEmpty {
                                    CardFootnote(text: section.footer)
                                }
                            }
                        }
                        Text(viewModel.datesFootnote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, 8)
                .padding(.bottom, Spacing.scrollBottom)
            }
        }
    }
}

// medicines in a section
struct MedicineRowList: View {
    let rows: [MedicineRow]
    let viewModel: MedicinesViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // hairlines indented past the icon
        DividedList(items: rows, inset: 46) { row in
            NavigationLink(value: row.medicine) {
                MedicineRowView(row: row)
            }
            .buttonStyle(.plain)
            // touch and hold = the quick action
            .contextMenu {
                if !row.swipeTitle.isEmpty {
                    Button(row.swipeTitle, systemImage: "checkmark") {
                        Motion.perform(reduceMotion) { viewModel.swipe(row, in: context) }
                    }
                }
            }
        }
    }
}

// one medicine row
struct MedicineRowView: View {
    let row: MedicineRow

    var body: some View {
        HStack(spacing: 12) {
            MedicineIcon(pillShape: row.pillShape, pillColor: row.pillColor,
                         symbol: row.symbol, tone: row.tone, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.body.weight(.semibold))
                Text(row.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !row.trailing.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    if !row.trailingCaption.isEmpty {
                        Text(row.trailingCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(row.trailing)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(row.tone.color)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            Chevron()
        }
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenLabel)
        .accessibilityAddTraits(.isButton)
    }
}

// search results
struct SearchResultsCard: View {
    let viewModel: MedicinesViewModel
    let query: String

    var body: some View {
        let results = viewModel.searchResults(for: query)
        SectionCard(title: viewModel.searchHeader, symbol: viewModel.searchSymbol,
                    collapsible: false, rememberAs: "medicines.search") {
            if results.isEmpty {
                Label(viewModel.noMatchText(for: query), systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.rowVertical)
            }
            DividedList(items: results, inset: 46) { result in
                NavigationLink(value: result.medicine) {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
            }
            CardFootnote(text: viewModel.searchFooter)
        }
    }
}

// one search result
struct SearchResultRow: View {
    let result: MedicineSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: result.symbol, tone: result.tone, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body.weight(.semibold))
                Text(result.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(result.tone.color)
                Text(result.sentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    MedicinesView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    MedicinesView()
}
