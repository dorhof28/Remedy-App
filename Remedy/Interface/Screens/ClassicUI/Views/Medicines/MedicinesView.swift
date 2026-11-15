//
//  MedicinesView.swift
//  Remedy
//
//  classic medicines tab (screens 30 and 31): search, filter chips, then the groups by what to do
//

import SwiftUI
import SwiftData

// classic medicines tab
struct MedicinesView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    // redraws when a dose is logged
    @Query private var logs: [DoseLog]

    @Environment(\.switchTab) private var switchTab
    @Environment(\.openURL) private var openURL

    // UI only what is typed, the picked chip and what is open
    @State private var query = ""
    @State private var filter: MedicineTabGroup?
    @State private var isAdding = false
    @State private var isAddingPapers = false
    @State private var opened: MedicineInstruction?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                content(MedicinesViewModel(plan: plans.first, now: AppClock.now()))
            }
            .navigationTitle("Medicines")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $opened) { MedicineDetailView(medicine: $0) }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Search, like Advil or Tylenol")
            .helpButtons()
            .sampleDataFooter()
            .sheet(isPresented: $isAdding) {
                if let plan = plans.first { MedicineEditView(medicine: nil, plan: plan, now: AppClock.now()) }
            }
            .sheet(isPresented: $isAddingPapers) {
                ScanFlowView(isAddingPapers: true, planHasSurgeryDate: plans.first?.surgeryDate != nil)
            }
        }
    }

    @ViewBuilder
    private func content(_ screen: MedicinesViewModel) -> some View {
        if plans.first == nil || screen.isListEmpty {
            HeroScreen(symbol: "doc.text", title: screen.emptyTitle, text: screen.emptyText) {
                PrimaryButton(title: screen.addPapersButton, symbol: "camera") { isAddingPapers = true }
            }
        } else if screen.isSearching(query) {
            searchList(screen)
        } else {
            List {
                Section {
                    // one row, every tile the same width
                    EqualFilterTiles(tiles: screen.chips.map {
                        EqualFilterTiles.Tile(id: $0.group, word: $0.title, count: $0.count, symbol: $0.symbol ?? "list.bullet",
                                              tone: $0.group == .stopped ? .stop : .info)
                    }, selection: $filter)
                        .plainListRow()
                }
                ForEach(screen.shown(filter)) { group in
                    Section {
                        ForEach(group.lines) { row($0) }
                    } header: {
                        ListSectionHeader(title: group.title)
                    }
                }
                Section {
                    Button { isAdding = true } label: {
                        ListRow(symbol: "plus", title: screen.addMedicineButton)
                    }
                    .buttonStyle(.plain)
                }
            }
            .remedyList()
        }
    }

    // screen 31, matches by group then what the plan has
    private func searchList(_ screen: MedicinesViewModel) -> some View {
        let results = screen.search(query)
        return List {
            if results.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HeroMessage(symbol: "magnifyingglass", title: screen.noMatchTitle, text: screen.noMatchText(query))
                            .frame(maxWidth: .infinity)
                        SecondaryButton(title: screen.askButton, symbol: "questionmark.bubble") { switchTab?(.ask) }
                        if let call = screen.officeCall {
                            SecondaryButton(title: screen.callOfficeButton, symbol: "phone.fill") { openURL(call) }
                        }
                    }
                    .plainListRow()
                }
            }
            ForEach(results) { group in
                Section {
                    ForEach(group.lines) { row($0) }
                } header: {
                    ListSectionHeader(title: group.title)
                } footer: {
                    if !group.footer.isEmpty {
                        Text(group.footer)
                            .font(.subheadline)
                            .foregroundStyle(Color.ink2)
                    }
                }
            }
        }
        .remedyList()
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func row(_ line: MedicineLine) -> some View {
        let label = ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                            subtitleTone: line.subtitleTone, showsChevron: line.opens)
        if let medicine = line.medicine {
            // a button, so the list adds no second chevron
            Button { opened = medicine } label: { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}

#Preview("After surgery", traits: .afterSurgerySample) {
    MedicinesView()
}
